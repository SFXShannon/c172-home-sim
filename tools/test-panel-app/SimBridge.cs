using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using static C172TestPanel.SimConnectNative;

namespace C172TestPanel
{
    /// <summary>
    /// Sends the panel straight to Microsoft Flight Simulator through SimConnect, so
    /// nothing needs binding in the sim. What each control sends is in sim-map.txt
    /// (in %LOCALAPPDATA%\C172TestPanel), which can be edited without rebuilding.
    ///
    /// Switches (brake, fuel, key) are sent when they change, and all of them again
    /// when a flight starts or an aircraft loads, so the sim matches the panel.
    /// </summary>
    public sealed class SimBridge : IDisposable
    {
        // ---- mapping ------------------------------------------------------------

        public const string DefaultMap =
@"# What each panel control sends to Microsoft Flight Simulator.
# Edit and save; the app picks the changes up within a couple of seconds.
#
#   K:EVENT [value]     a classic key event (works in most aircraft)
#   B:INPUT_EVENT value an aircraft input event (the 2024 aircraft use these);
#                       only sent if the loaded aircraft has that input event
#   $N                  for the levers: the lever position scaled to 0..N
#   a ; b               try a, and if the aircraft doesn't have it, b
#   a & b               send both
#
# input-events.txt (next to this file) lists every input event the loaded
# aircraft has, written each time an aircraft loads.

throttle      = K:THROTTLE_SET $16383
mixture       = K:MIXTURE_SET $16383
prop          = K:PROP_PITCH_SET $16383

brake.set     = B:LANDING_GEAR_PARKINGBRAKE 1 ; K:PARKING_BRAKE_SET 1
brake.release = B:LANDING_GEAR_PARKINGBRAKE 0 ; K:PARKING_BRAKE_SET 0

fuel.left     = K:FUEL_SELECTOR_LEFT
fuel.both     = K:FUEL_SELECTOR_ALL
fuel.right    = K:FUEL_SELECTOR_RIGHT
fuel.off      = K:FUEL_SELECTOR_OFF

key.off       = K:MAGNETO_OFF
key.r         = K:MAGNETO_RIGHT
key.l         = K:MAGNETO_LEFT
key.both      = K:MAGNETO_BOTH
key.start     = K:MAGNETO_START

trim.down     = K:ELEV_TRIM_DN
trim.up       = K:ELEV_TRIM_UP
";

        public static string MapPath => Path.Combine(Log.Folder, "sim-map.txt");
        public static string EventsPath => Path.Combine(Log.Folder, "input-events.txt");

        class Command
        {
            public bool IsInput;      // B: input event, else K: key event
            public string Name;
            public double Value;
            public double AxisMax;    // > 0 when the value is "$N"
        }

        // action -> alternatives -> commands sent together
        Dictionary<string, List<List<Command>>> map = new Dictionary<string, List<List<Command>>>();
        DateTime mapTime;

        void LoadMap()
        {
            try
            {
                Directory.CreateDirectory(Log.Folder);
                if (!File.Exists(MapPath)) File.WriteAllText(MapPath, DefaultMap);
                var t = File.GetLastWriteTimeUtc(MapPath);
                if (t == mapTime) return;
                mapTime = t;
                map = ParseMap(File.ReadAllLines(MapPath));
                Log.Write($"sim: loaded sim-map.txt ({map.Count} controls)");
                ResyncSoon(0.2);
            }
            catch (Exception ex) { Log.Write("sim: sim-map.txt: " + ex.Message); }
        }

        static Dictionary<string, List<List<Command>>> ParseMap(IEnumerable<string> lines)
        {
            var m = new Dictionary<string, List<List<Command>>>(StringComparer.OrdinalIgnoreCase);
            foreach (var raw in lines)
            {
                var line = raw.Split('#')[0].Trim();
                int eq = line.IndexOf('=');
                if (eq <= 0) continue;
                string key = line.Substring(0, eq).Trim();
                var alts = new List<List<Command>>();
                foreach (var alt in line.Substring(eq + 1).Split(';'))
                {
                    var cmds = new List<Command>();
                    foreach (var part in alt.Split('&'))
                    {
                        var w = part.Trim().Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
                        if (w.Length == 0) continue;
                        var c = new Command();
                        string n = w[0];
                        if (n.StartsWith("B:", StringComparison.OrdinalIgnoreCase)) { c.IsInput = true; n = n.Substring(2); }
                        else if (n.StartsWith("K:", StringComparison.OrdinalIgnoreCase)) n = n.Substring(2);
                        c.Name = n.ToUpperInvariant();
                        if (w.Length > 1)
                        {
                            if (w[1].StartsWith("$"))
                                double.TryParse(w[1].Substring(1), NumberStyles.Float, CultureInfo.InvariantCulture, out c.AxisMax);
                            else
                                double.TryParse(w[1], NumberStyles.Float, CultureInfo.InvariantCulture, out c.Value);
                        }
                        cmds.Add(c);
                    }
                    if (cmds.Count > 0) alts.Add(cmds);
                }
                if (alts.Count > 0) m[key] = alts;
            }
            return m;
        }

        // ---- connection -----------------------------------------------------------

        IntPtr handle = IntPtr.Zero;
        DateTime nextConnect = DateTime.MinValue;
        readonly Dictionary<string, uint> keyEvents = new Dictionary<string, uint>();
        readonly Dictionary<string, ulong> inputEvents = new Dictionary<string, ulong>();
        readonly List<string> enumBuffer = new List<string>();
        uint nextEventId = 100;
        const uint EvSimStart = 1, EvAircraftLoaded = 2, ReqInputEvents = 10;

        public bool Enabled { get; set; }
        public bool Connected => handle != IntPtr.Zero;
        public string Aircraft { get; private set; } = "";
        public string LastSent { get; private set; } = "";
        public string Problem { get; private set; } = "";
        public int InputEventCount => inputEvents.Count;

        void TryConnect()
        {
            if (DateTime.UtcNow < nextConnect) return;
            nextConnect = DateTime.UtcNow.AddSeconds(5);
            try
            {
                if (SimConnect_Open(out IntPtr h, "C172 Test Panel", IntPtr.Zero, 0, IntPtr.Zero, 0) != 0 || h == IntPtr.Zero)
                {
                    Problem = "";
                    return;       // sim not running
                }
                handle = h;
                keyEvents.Clear();
                inputEvents.Clear();
                Aircraft = "";
                SimConnect_SubscribeToSystemEvent(handle, EvSimStart, "SimStart");
                SimConnect_SubscribeToSystemEvent(handle, EvAircraftLoaded, "AircraftLoaded");
                SimConnect_EnumerateInputEvents(handle, ReqInputEvents);
                Log.Write("sim: connected to Microsoft Flight Simulator");
                ResyncSoon(1);
            }
            catch (DllNotFoundException)
            {
                Problem = "SimConnect.dll is missing: keep it next to the exe.";
                nextConnect = DateTime.UtcNow.AddSeconds(30);
            }
            catch (BadImageFormatException)
            {
                Problem = "SimConnect.dll doesn't match this exe (needs the 64-bit one).";
                nextConnect = DateTime.UtcNow.AddSeconds(30);
            }
        }

        void Disconnect(string why)
        {
            if (handle != IntPtr.Zero)
            {
                try { SimConnect_Close(handle); } catch { }
                Log.Write("sim: disconnected (" + why + ")");
            }
            handle = IntPtr.Zero;
            inputEvents.Clear();
            Aircraft = "";
        }

        public void Dispose() => Disconnect("app closed");

        void Pump()
        {
            for (int n = 0; n < 50 && handle != IntPtr.Zero; n++)
            {
                if (SimConnect_GetNextDispatch(handle, out IntPtr p, out uint size) != 0 || p == IntPtr.Zero) return;
                int id = Marshal.ReadInt32(p, OffId);
                switch (id)
                {
                    case RECV_QUIT:
                        Disconnect("sim closed");
                        nextConnect = DateTime.UtcNow.AddSeconds(5);
                        return;
                    case RECV_EXCEPTION:
                        Log.Write($"sim: SimConnect exception {Marshal.ReadInt32(p, OffException)}");
                        break;
                    case RECV_EVENT:
                        if ((uint)Marshal.ReadInt32(p, OffEventId) == EvSimStart)
                        {
                            Log.Write("sim: flight started");
                            SimConnect_EnumerateInputEvents(handle, ReqInputEvents);
                            ResyncSoon(3);
                        }
                        break;
                    case RECV_EVENT_FILENAME:
                        if ((uint)Marshal.ReadInt32(p, OffEventId) == EvAircraftLoaded)
                        {
                            string file = Marshal.PtrToStringAnsi(p + OffFileName) ?? "";
                            Aircraft = AircraftName(file);
                            Log.Write("sim: aircraft loaded: " + file);
                            inputEvents.Clear();
                            SimConnect_EnumerateInputEvents(handle, ReqInputEvents);
                            ResyncSoon(3);
                        }
                        break;
                    case RECV_ENUMERATE_INPUT_EVENTS:
                        ReadInputEvents(p);
                        break;
                }
            }
        }

        static string AircraftName(string file)
        {
            // ...\SimObjects\Airplanes\Asobo_C172sp_AS1000\aircraft.cfg -> Asobo_C172sp_AS1000
            try
            {
                var dir = Path.GetDirectoryName(file.Replace('/', '\\'));
                var name = Path.GetFileName(dir);
                return string.IsNullOrEmpty(name) ? file : name;
            }
            catch { return file; }
        }

        void ReadInputEvents(IntPtr p)
        {
            int count = Marshal.ReadInt32(p, OffListSize);
            int entry = Marshal.ReadInt32(p, OffListEntry);
            int outOf = Marshal.ReadInt32(p, OffListOutOf);
            if (entry == 0) enumBuffer.Clear();
            for (int i = 0; i < count; i++)
            {
                IntPtr d = p + OffListData + i * InputEventSize;
                string name = Marshal.PtrToStringAnsi(d) ?? "";
                if (name.Length > 64) name = name.Substring(0, 64);
                ulong hash = (ulong)Marshal.ReadInt64(d, 64);
                int type = Marshal.ReadInt32(d, 72);
                if (name.Length == 0) continue;
                inputEvents[name.ToUpperInvariant()] = hash;
                enumBuffer.Add(type == 1 ? name + "   (text)" : name);
            }
            if (entry + 1 >= outOf)
            {
                try
                {
                    var sb = new StringBuilder();
                    sb.AppendLine($"# Input events of {(Aircraft.Length > 0 ? Aircraft : "the loaded aircraft")}, {DateTime.Now:yyyy-MM-dd HH:mm}");
                    sb.AppendLine("# Use them in sim-map.txt as B:NAME value");
                    foreach (var n in enumBuffer.OrderBy(x => x)) sb.AppendLine(n);
                    File.WriteAllText(EventsPath, sb.ToString());
                }
                catch { }
                Log.Write($"sim: {inputEvents.Count} input events");
                ResyncSoon(0.5);
            }
        }

        // ---- sending --------------------------------------------------------------

        bool Send(string action, int axis = -1)
        {
            if (!map.TryGetValue(action, out var alts)) return false;
            foreach (var alt in alts)
            {
                // an alternative is usable if every input event in it exists on this aircraft
                if (alt.Any(c => c.IsInput && !inputEvents.ContainsKey(c.Name))) continue;
                var sent = new List<string>();
                foreach (var c in alt)
                {
                    double v = c.AxisMax > 0 && axis >= 0 ? Math.Round(axis / 1023.0 * c.AxisMax, 3) : c.Value;
                    if (c.IsInput)
                    {
                        SimConnect_SetInputEvent(handle, inputEvents[c.Name], 8, ref v);
                        sent.Add($"B:{c.Name} {v.ToString(CultureInfo.InvariantCulture)}");
                    }
                    else
                    {
                        if (!keyEvents.TryGetValue(c.Name, out uint id))
                        {
                            id = nextEventId++;
                            SimConnect_MapClientEventToSimEvent(handle, id, c.Name);
                            keyEvents[c.Name] = id;
                        }
                        uint data = (uint)(int)Math.Round(v);
                        SimConnect_TransmitClientEvent(handle, OBJECT_ID_USER, id, data,
                                                       GROUP_PRIORITY_HIGHEST, EVENT_FLAG_GROUPID_IS_PRIORITY);
                        sent.Add($"K:{c.Name}" + (c.AxisMax > 0 || c.Value != 0 ? " " + data : ""));
                    }
                }
                if (axis < 0)
                {
                    LastSent = $"{action}: {string.Join(" & ", sent)}";
                    Log.Write("sim: " + LastSent);
                }
                return true;
            }
            return false;
        }

        // ---- panel state -> sim -----------------------------------------------------

        LiveData panel;
        readonly int[] sentAxis = { -100, -100, -100 };
        int sentBrake = -1, sentFuel = -1, sentKey = -1;
        long sentTrim = long.MinValue;
        DateTime resyncAt = DateTime.MaxValue, lastStart = DateTime.MinValue, nextMapCheck = DateTime.MinValue;

        static readonly string[] AxisActions = { "throttle", "mixture", "prop" };
        static readonly string[] FuelActions = { "fuel.left", "fuel.both", "fuel.right", "fuel.off" };
        static readonly string[] KeyActions = { "key.off", "key.r", "key.l", "key.both", "key.start" };

        /// <summary>The latest panel values; called for each live data line.</summary>
        public void Update(LiveData d) => panel = d;

        /// <summary>Send everything again shortly (after a flight starts, say).</summary>
        public void ResyncSoon(double seconds = 0)
        {
            var t = DateTime.UtcNow.AddSeconds(seconds);
            if (t < resyncAt || resyncAt == DateTime.MaxValue) resyncAt = t;
        }

        /// <summary>Call about 20 times a second from the UI thread.</summary>
        public void Tick()
        {
            if (DateTime.UtcNow >= nextMapCheck) { nextMapCheck = DateTime.UtcNow.AddSeconds(2); LoadMap(); }
            if (!Enabled)
            {
                if (Connected) Disconnect("turned off");
                return;
            }
            if (!Connected) { TryConnect(); if (!Connected) return; }
            try
            {
                Pump();
                if (Connected && panel != null) SendPanel(panel);
            }
            catch (Exception ex)
            {
                Log.Write("sim: " + ex.Message);
                Disconnect("error");
            }
        }

        void SendPanel(LiveData d)
        {
            if (DateTime.UtcNow >= resyncAt)
            {
                resyncAt = DateTime.MaxValue;
                for (int i = 0; i < 3; i++) sentAxis[i] = -100;
                sentBrake = sentFuel = sentKey = -1;
                Log.Write("sim: syncing the sim to the panel");
            }
            bool Btn(int i) => (d.Buttons & (1 << i)) != 0;

            // levers: send when they move
            for (int i = 0; i < 3; i++)
                if (Math.Abs(d.Out[i] - sentAxis[i]) >= 2 || (sentAxis[i] < 0))
                {
                    Send(AxisActions[i], d.Out[i]);
                    sentAxis[i] = d.Out[i];
                }

            // parking brake
            int brake = Btn(0) ? 1 : 0;
            if (brake != sentBrake) { Send(brake == 1 ? "brake.set" : "brake.release"); sentBrake = brake; }

            // fuel selector: only when exactly one position reads
            var fuel = Enumerable.Range(0, 4).Where(i => Btn(3 + i)).ToList();
            if (fuel.Count == 1 && fuel[0] != sentFuel) { Send(FuelActions[fuel[0]]); sentFuel = fuel[0]; }

            // ignition key: START is repeated while it's held, like holding the real key
            var key = Enumerable.Range(0, 5).Where(i => Btn(9 + i)).ToList();
            if (key.Count == 1)
            {
                int k = key[0];
                if (k != sentKey) { Send(KeyActions[k]); sentKey = k; lastStart = DateTime.UtcNow; }
                else if (k == 4 && (DateTime.UtcNow - lastStart).TotalMilliseconds > 200)
                {
                    lastStart = DateTime.UtcNow;
                    Send("key.start");
                }
            }

            // trim wheel: one step per click
            if (sentTrim == long.MinValue) sentTrim = d.Trim;
            long delta = d.Trim - sentTrim;
            if (Math.Abs(delta) > 200) delta = 0;     // the panel restarted and its count reset
            for (int i = 0; i < Math.Min(Math.Abs(delta), 40); i++) Send(delta > 0 ? "trim.down" : "trim.up");
            sentTrim = d.Trim;
        }
    }
}
