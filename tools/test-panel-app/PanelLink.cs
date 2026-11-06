using System;
using System.Collections.Generic;
using System.IO.Ports;
using System.Linq;
using System.Management;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace C172TestPanel
{
    /// <summary>A COM port as Windows lists it.</summary>
    public class PortInfo
    {
        public string Name;          // COM5
        public string Description;   // Arduino Leonardo (COM5)
        public bool LooksLikeBoard;  // a Leonardo / Micro / Pro Micro (ATmega32U4) USB ID

        public override string ToString() =>
            string.IsNullOrEmpty(Description) ? Name : Description;
    }

    /// <summary>Live values from the sketch's "D," line.</summary>
    public class LiveData
    {
        public int[] Raw = new int[3];
        public int[] Out = new int[3];
        public int Buttons;
        public int Pins;
        public long Trim;
    }

    /// <summary>Settings from the sketch's "CFG," line.</summary>
    public class PanelConfig
    {
        public bool RevThr, RevMix, RevProp, RevTrim, RevIgn, FuelToggle, AutoCal;
        public int TrimSteps, PulseMs;
        public int[] Lo = new int[3];
        public int[] Hi = new int[3];
        public int[] IgnMap;     // per key position OFF..START: pin index 0-4 or -1; null on firmware v2
    }

    /// <summary>
    /// Talks to test_panel.ino over the Pro Micro's USB serial port.
    /// Lines arrive on a background thread; LineReceived is raised there.
    /// </summary>
    public sealed class PanelLink : IDisposable
    {
        SerialPort port;
        Thread reader;
        volatile bool running;
        readonly object writeLock = new object();

        public string PortName { get; private set; }
        public bool IsOpen => port != null && port.IsOpen && running;

        public event Action<string> LineReceived;
        public event Action Lost;

        // A Pro Micro flashed as "Arduino Leonardo" (as the sketch says to), as
        // "Arduino Micro", or with SparkFun's Pro Micro board files. Only these are probed automatically:
        // opening an Uno resets it, and other USB serial devices (SimHub boards,
        // wheel bases) shouldn't be sent commands.
        static readonly string[] BoardIds =
        {
            "VID_2341&PID_8036", "VID_2A03&PID_8036", "VID_2341&PID_8037", "VID_2A03&PID_8037",
            "VID_1B4F&PID_9205", "VID_1B4F&PID_9206",
        };

        public static List<PortInfo> ListPorts()
        {
            var names = SerialPort.GetPortNames().Distinct().ToList();
            var list = names.Select(n => new PortInfo { Name = n }).ToList();
            try
            {
                using (var s = new ManagementObjectSearcher(
                    "SELECT Name, DeviceID FROM Win32_PnPEntity WHERE Name LIKE '%(COM%'"))
                {
                    foreach (ManagementObject o in s.Get())
                    {
                        string name = o["Name"] as string ?? "";
                        string id = (o["DeviceID"] as string ?? "").ToUpperInvariant();
                        var m = Regex.Match(name, @"\((COM\d+)\)");
                        if (!m.Success) continue;
                        var p = list.FirstOrDefault(x => x.Name == m.Groups[1].Value);
                        if (p == null) continue;
                        p.Description = name;
                        p.LooksLikeBoard = BoardIds.Any(v => id.Contains(v));
                    }
                }
            }
            catch { /* WMI unavailable: plain COM names are fine */ }
            return list.OrderByDescending(p => p.LooksLikeBoard)
                       .ThenBy(p => PortNumber(p.Name)).ToList();
        }

        static int PortNumber(string name) =>
            int.TryParse(new string(name.Where(char.IsDigit).ToArray()), out int n) ? n : 999;

        static SerialPort MakePort(string name) => new SerialPort(name, 115200)
        {
            // The Pro Micro only sends serial data while DTR is on.
            DtrEnable = true,
            RtsEnable = true,
            NewLine = "\n",
            ReadTimeout = 400,
            WriteTimeout = 400,
        };

        /// <summary>
        /// Opens a port, giving up after a few seconds: a USB serial port whose
        /// device has stopped responding can hang Open() forever.
        /// </summary>
        static SerialPort OpenPort(string name, int timeoutMs = 3000)
        {
            var p = MakePort(name);
            var t = Task.Run(() => p.Open());
            try
            {
                if (!t.Wait(timeoutMs))
                {
                    Log.Write($"{name}: open timed out");
                    throw new TimeoutException($"{name} didn't open (the device isn't responding)");
                }
            }
            catch (AggregateException ae) { throw ae.InnerException; }
            return p;
        }

        /// <summary>
        /// Opens a port briefly and asks "HELLO". Returns the firmware version
        /// if test_panel.ino answers, otherwise null.
        /// </summary>
        public static string Probe(string name, int timeoutMs = 1800)
        {
            try
            {
                using (var p = OpenPort(name))
                {
                    Thread.Sleep(150);
                    p.DiscardInBuffer();
                    var until = DateTime.UtcNow.AddMilliseconds(timeoutMs);
                    var nextHello = DateTime.MinValue;
                    while (DateTime.UtcNow < until)
                    {
                        if (DateTime.UtcNow >= nextHello)
                        {
                            p.Write("STREAM 0\nHELLO\n");
                            nextHello = DateTime.UtcNow.AddMilliseconds(500);
                        }
                        try
                        {
                            string line = p.ReadLine().Trim();
                            Log.Write($"{name} probe reply: {line}");
                            if (line.StartsWith("C172TP,")) return line.Substring(7);
                        }
                        catch (TimeoutException) { }
                    }
                }
            }
            catch (Exception ex) { Log.Write($"{name} probe: {ex.Message}"); }
            Log.Write($"{name} probe: no answer");
            return null;
        }

        public void Open(string name)
        {
            Close();
            var p = OpenPort(name);
            Log.Write($"{name}: opened");
            port = p;
            PortName = name;
            running = true;
            reader = new Thread(ReadLoop) { IsBackground = true, Name = "panel reader" };
            reader.Start();
        }

        void ReadLoop()
        {
            var p = port;
            while (running)
            {
                string line;
                try { line = p.ReadLine(); }
                catch (TimeoutException) { continue; }
                catch (Exception ex)
                {
                    Log.Write($"{PortName} read: {ex.GetType().Name} {ex.Message}");
                    if (running) { running = false; Lost?.Invoke(); }
                    return;
                }
                line = line.Trim();
                if (line.Length > 0) LineReceived?.Invoke(line);
            }
        }

        public bool Send(string command)
        {
            var p = port;
            if (p == null || !running) return false;
            try
            {
                lock (writeLock) p.Write(command + "\n");
                return true;
            }
            catch (Exception ex)
            {
                Log.Write($"{PortName} write: {ex.GetType().Name} {ex.Message}");
                if (running) { running = false; Lost?.Invoke(); }
                return false;
            }
        }

        public void Close()
        {
            running = false;
            var p = port;
            port = null;
            if (p != null)
            {
                try { if (p.IsOpen) { lock (writeLock) p.Write("STREAM 0\n"); } } catch { }
                try { p.Close(); } catch { }
                try { p.Dispose(); } catch { }
            }
            reader = null;
        }

        public void Dispose() => Close();

        // ---- parsing ----------------------------------------------------------

        public static LiveData ParseData(string line)
        {
            // D,raw0,raw1,raw2,out0,out1,out2,buttons(hex),pins(hex),trim
            var f = line.Split(',');
            if (f.Length < 10 || f[0] != "D") return null;
            try
            {
                var d = new LiveData();
                for (int i = 0; i < 3; i++)
                {
                    d.Raw[i] = int.Parse(f[1 + i]);
                    d.Out[i] = int.Parse(f[4 + i]);
                }
                d.Buttons = Convert.ToInt32(f[7], 16);
                d.Pins = Convert.ToInt32(f[8], 16);
                d.Trim = long.Parse(f[9]);
                return d;
            }
            catch { return null; }
        }

        public static PanelConfig ParseConfig(string line)
        {
            // CFG,revThr,revMix,revProp,revTrim,revIgn,fuelToggle,autoCal,trimSteps,pulseMs,lo0,hi0,lo1,hi1,lo2,hi2
            var f = line.Split(',');
            if (f.Length < 16 || f[0] != "CFG") return null;
            try
            {
                int n(int i) => int.Parse(f[i]);
                var c = new PanelConfig
                {
                    RevThr = n(1) != 0, RevMix = n(2) != 0, RevProp = n(3) != 0,
                    RevTrim = n(4) != 0, RevIgn = n(5) != 0, FuelToggle = n(6) != 0,
                    AutoCal = n(7) != 0, TrimSteps = n(8), PulseMs = n(9),
                };
                for (int i = 0; i < 3; i++) { c.Lo[i] = n(10 + i * 2); c.Hi[i] = n(11 + i * 2); }
                if (f.Length > 16 && f[16].Length == 5)
                    c.IgnMap = f[16].Select(ch => ch >= '0' && ch <= '4' ? ch - '0' : -1).ToArray();
                return c;
            }
            catch { return null; }
        }
    }
}

namespace C172TestPanel
{
    /// <summary>A small log and the last port that worked, in %LOCALAPPDATA%\C172TestPanel.</summary>
    static class Log
    {
        static readonly object gate = new object();
        public static readonly string Folder = System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "C172TestPanel");
        static string LogFile => System.IO.Path.Combine(Folder, "log.txt");
        static string PortFile => System.IO.Path.Combine(Folder, "last-port.txt");

        public static void Write(string text)
        {
            try
            {
                lock (gate)
                {
                    System.IO.Directory.CreateDirectory(Folder);
                    var fi = new System.IO.FileInfo(LogFile);
                    if (fi.Exists && fi.Length > 256 * 1024) fi.Delete();
                    System.IO.File.AppendAllText(LogFile, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}  {text}\r\n");
                }
            }
            catch { }
        }

        public static string LastPort
        {
            get { try { return System.IO.File.ReadAllText(PortFile).Trim(); } catch { return null; } }
            set { try { System.IO.Directory.CreateDirectory(Folder); System.IO.File.WriteAllText(PortFile, value ?? ""); } catch { } }
        }
    }
}

namespace C172TestPanel
{
    /// <summary>Tiny key=value settings file in %LOCALAPPDATA%\C172TestPanel.</summary>
    static class Settings
    {
        static string FilePath => System.IO.Path.Combine(Log.Folder, "settings.txt");

        public static string Get(string key, string fallback)
        {
            try
            {
                foreach (var line in System.IO.File.ReadAllLines(FilePath))
                {
                    int eq = line.IndexOf('=');
                    if (eq > 0 && line.Substring(0, eq) == key) return line.Substring(eq + 1);
                }
            }
            catch { }
            return fallback;
        }

        public static void Set(string key, string value)
        {
            try
            {
                System.IO.Directory.CreateDirectory(Log.Folder);
                var lines = System.IO.File.Exists(FilePath)
                    ? System.IO.File.ReadAllLines(FilePath).Where(l => !l.StartsWith(key + "=")).ToList()
                    : new List<string>();
                lines.Add(key + "=" + value);
                System.IO.File.WriteAllLines(FilePath, lines);
            }
            catch { }
        }
    }
}
