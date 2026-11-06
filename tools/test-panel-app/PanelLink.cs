using System;
using System.Collections.Generic;
using System.IO.Ports;
using System.Linq;
using System.Management;
using System.Text.RegularExpressions;
using System.Threading;

namespace C172TestPanel
{
    /// <summary>A COM port as Windows lists it.</summary>
    public class PortInfo
    {
        public string Name;          // COM5
        public string Description;   // Arduino Leonardo (COM5)
        public bool LooksLikeBoard;  // Arduino / SparkFun USB IDs

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

        // Arduino (Leonardo / Pro Micro sketch), SparkFun, Arduino.org
        static readonly string[] BoardVids = { "VID_2341", "VID_1B4F", "VID_2A03" };

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
                        p.LooksLikeBoard = BoardVids.Any(v => id.Contains(v)) ||
                                           name.IndexOf("Arduino", StringComparison.OrdinalIgnoreCase) >= 0;
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
        /// Opens a port briefly and asks "HELLO". Returns the firmware version
        /// if test_panel.ino answers, otherwise null.
        /// </summary>
        public static string Probe(string name, int timeoutMs = 1800)
        {
            try
            {
                using (var p = MakePort(name))
                {
                    p.Open();
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
                            if (line.StartsWith("C172TP,")) return line.Substring(7);
                        }
                        catch (TimeoutException) { }
                    }
                }
            }
            catch { }
            return null;
        }

        public void Open(string name)
        {
            Close();
            var p = MakePort(name);
            p.Open();
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
                catch
                {
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
            catch
            {
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
                return c;
            }
            catch { return null; }
        }
    }
}
