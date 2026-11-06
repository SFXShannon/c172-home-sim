using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Threading;
using System.Windows.Forms;

namespace C172TestPanel
{
    public class MainForm : Form
    {
        // ---- connection
        readonly PanelLink link = new PanelLink();
        ComboBox portBox;
        FlatBtn rescanBtn, connectBtn;
        Label statusLabel;
        string firmware;              // version from HELLO, null until it answers
        string wantedPort;            // port to come back to after an unplug
        DateTime lastData = DateTime.MinValue, openedAt = DateTime.MinValue, lastRetry = DateTime.MinValue;
        bool scanning;

        // ---- live view
        readonly LeverView[] levers = { new LeverView("Throttle"), new LeverView("Mixture"), new LeverView("Prop") };
        Lamp brakeLamp, brakeSetLamp, brakeRelLamp, trimDnLamp, trimUpLamp;
        readonly Lamp[] fuelLamps = new Lamp[4];
        readonly Lamp[] ignLamps = new Lamp[5];
        readonly Lamp[] buttonLamps = new Lamp[14];
        readonly Lamp[] pinLamps = new Lamp[12];
        Label trimCountLabel, fuelNote;
        long trimZero, trimLast;
        LiveData last;

        // ---- setup
        CheckBox revThr, revMix, revProp, revTrim, fuelToggle, autoCal;
        FlatBtn keyBtn;
        KeyMapDialog keyDialog;
        NumericUpDown trimSteps, pulseMs;
        readonly NumericUpDown[] loBox = new NumericUpDown[3], hiBox = new NumericUpDown[3];
        FlatBtn calBtn, calCancelBtn, saveBtn, undoBtn, defaultsBtn;
        Label calHint, dirtyLabel;
        bool loading;                 // true while filling controls from the board
        bool dirty;
        bool calibrating;
        readonly int[] capLo = new int[3], capHi = new int[3];
        PanelConfig config;

        readonly System.Windows.Forms.Timer tick = new System.Windows.Forms.Timer { Interval = 1000 };

        // ---- flight simulator
        readonly SimBridge sim = new SimBridge();
        readonly System.Windows.Forms.Timer simTick = new System.Windows.Forms.Timer { Interval = 50 };
        CheckBox simOn;
        Label simStatus, simLast;

        static readonly string[] FuelNames = { "LEFT", "BOTH", "RIGHT", "OFF" };
        static readonly string[] IgnNames = { "OFF", "R", "L", "BOTH", "START" };
        static readonly string[] ButtonTips =
        {
            "Parking brake set (held)", "Parking brake just set (pulse)", "Parking brake just released (pulse)",
            "Fuel LEFT", "Fuel BOTH", "Fuel RIGHT", "Fuel OFF",
            "Trim nose down (pulse per click)", "Trim nose up (pulse per click)",
            "Key OFF", "Key R", "Key L", "Key BOTH", "Key START",
        };
        static readonly string[] PinNames =
        {
            "2  brake", "3  fuel L", "4  fuel BOTH", "5  fuel R", "6  fuel OFF", "7  trim A",
            "8  trim B", "9  key OFF", "10  key R", "14  key L", "15  key BOTH", "16  key START",
        };

        readonly bool demo;

        public MainForm(bool demo = false)
        {
            this.demo = demo;
            Text = "C172 Test Panel";
            AutoScaleDimensions = new SizeF(96f, 96f);
            AutoScaleMode = AutoScaleMode.Dpi;
            BackColor = Theme.Back;
            ForeColor = Theme.Text;
            Font = Theme.Body;
            ClientSize = new Size(1080, 818);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            DoubleBuffered = true;
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

            BuildTopBar();
            BuildLive();
            BuildSetup();
            BuildSim();

            link.LineReceived += line => { try { BeginInvoke((Action)(() => OnLine(line))); } catch { } };
            link.Lost += () => { try { BeginInvoke((Action)OnLost); } catch { } };
            tick.Tick += (s, e) => OnTick();
            simTick.Tick += (s, e) => { sim.Tick(); UpdateSimStatus(); };
            tick.Start();

            SetConnectedUi(false);
            Theme.UiScale = ClientSize.Width / 1080f;
            Resize += (s, e) => { if (ClientSize.Width > 0) Theme.UiScale = ClientSize.Width / 1080f; Invalidate(true); };
            if (!demo) Shown += (s, e) => Rescan(autoConnect: true);
            else tick.Stop();
            if (!demo) simTick.Start();
        }

        protected override bool ShowWithoutActivation => demo;

        /// <summary>Fills the window with sample values and saves it as a PNG.</summary>
        public void SaveDemoScreenshot(string path)
        {
            StartPosition = FormStartPosition.Manual;
            Location = new Point(-20000, -20000);
            ShowInTaskbar = false;
            Show();
            SetConnectedUi(true);
            connectBtn.Text = "Disconnect";
            portBox.Items.Add(new PortInfo { Name = "COM4", Description = "Arduino Leonardo (COM4)" });
            portBox.SelectedIndex = 0;
            Status("● Connected   COM4 · firmware v3", Theme.Green);
            ShowConfig(new PanelConfig
            {
                AutoCal = true, TrimSteps = 4, PulseMs = 40,
                Lo = new[] { 38, 41, 36 }, Hi = new[] { 987, 990, 984 },
            });
            int Out(int raw, int lo, int hi) => Math.Max(0, Math.Min(1023, (raw - lo - 6) * 1023 / (hi - lo - 12)));
            ShowLive(new LiveData
            {
                Raw = new[] { 801, 990, 512 },
                Out = new[] { Out(801, 38, 987), 1023, Out(512, 36, 984) },
                // brake set, fuel BOTH, key BOTH, trim nose-down pulse
                Buttons = (1 << 0) | (1 << 4) | (1 << 12) | (1 << 7),
                // pins: brake(2) LOW, fuel BOTH (4), trim A (7), key BOTH (15)
                Pins = (1 << 0) | (1 << 2) | (1 << 5) | (1 << 10),
                Trim = 7,
            });
            SetDirty(true);
            simOn.Checked = true;
            simStatus.Text = "● Connected to MSFS   ·   Asobo_C172SP_Classic   ·   312 input events";
            simStatus.ForeColor = Theme.Green;
            simLast.Text = "Last sent   fuel.both: K:FUEL_SELECTOR_ALL";
            Application.DoEvents();
            using (var bmp = new Bitmap(ClientSize.Width, ClientSize.Height))
            {
                DrawClient(bmp);
                bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png);
            }
            Close();
        }

        void DrawClient(Bitmap bmp)
        {
            // DrawToBitmap draws the whole window including the title bar; draw
            // just the client area by drawing each top-level control in place.
            using (var g = Graphics.FromImage(bmp)) g.Clear(BackColor);
            foreach (Control c in Controls.Cast<Control>().Reverse())
            {
                if (!c.Visible) continue;
                using (var part = new Bitmap(c.Width, c.Height))
                {
                    c.DrawToBitmap(part, new Rectangle(0, 0, c.Width, c.Height));
                    using (var g = Graphics.FromImage(bmp)) g.DrawImage(part, c.Left, c.Top);
                }
            }
        }

        // =====================================================================
        //  layout
        // =====================================================================

        Label MakeLabel(Control parent, string text, int x, int y, Font font = null, Color? color = null, int w = 0)
        {
            var l = new Label
            {
                Text = text, Left = x, Top = y, AutoSize = w == 0,
                Font = font ?? Theme.Body, ForeColor = color ?? Theme.Text,
                BackColor = parent is Card ? Theme.Card : parent.BackColor,
            };
            if (w > 0) { l.Width = w; l.Height = 18; }
            parent.Controls.Add(l);
            return l;
        }

        Card AddCard(string title, int x, int y, int w, int h)
        {
            var c = new Card(title) { Left = x, Top = y, Width = w, Height = h };
            Controls.Add(c);
            return c;
        }

        void BuildTopBar()
        {
            var bar = new Panel { Left = 0, Top = 0, Width = 1080, Height = 52, BackColor = Theme.Card };
            Controls.Add(bar);
            MakeLabel(bar, "C172 TEST PANEL", 16, 16, Theme.Bold, Theme.Accent);

            portBox = new ComboBox
            {
                Left = 168, Top = 14, Width = 300, DropDownStyle = ComboBoxStyle.DropDownList,
                FlatStyle = FlatStyle.Flat, BackColor = Theme.Input, ForeColor = Theme.Text,
            };
            bar.Controls.Add(portBox);

            rescanBtn = new FlatBtn("Rescan") { Left = 476, Top = 13, Width = 80, Height = 27 };
            rescanBtn.Click += (s, e) => Rescan(autoConnect: !link.IsOpen);
            bar.Controls.Add(rescanBtn);

            connectBtn = new FlatBtn("Connect", primary: true) { Left = 564, Top = 13, Width = 110, Height = 27 };
            connectBtn.Click += (s, e) => { if (link.IsOpen || wantedPort != null) Disconnect(); else ConnectSelected(); };
            bar.Controls.Add(connectBtn);

            statusLabel = MakeLabel(bar, "", 684, 18, Theme.Body, Theme.Dim);
            statusLabel.AutoSize = false;
            statusLabel.Width = 380;
            statusLabel.Height = 20;
            statusLabel.TextAlign = ContentAlignment.MiddleRight;
        }

        void BuildLive()
        {
            const int L = 16, W = 660;

            // levers
            var lv = AddCard("Levers   ·   axis value Windows sees, raw pot reading below", L, 64, W, 248);
            for (int i = 0; i < 3; i++)
            {
                levers[i].SetBounds(14, 34 + i * 70, W - 28, 62);
                lv.Controls.Add(levers[i]);
            }

            // brake / fuel / trim
            var br = AddCard("Parking brake", L, 324, 176, 124);
            brakeLamp = AddLamp(br, "RELEASED", 14, 32, 148, 40);
            brakeLamp.Font = Theme.Bold;
            brakeLamp.OnColor = Theme.Red;
            brakeSetLamp = AddLamp(br, "set ▸", 14, 82, 70, 26, Theme.Accent);
            brakeRelLamp = AddLamp(br, "release ▸", 90, 82, 72, 26, Theme.Accent);

            var fu = AddCard("Fuel selector", L + 188, 324, 236, 124);
            for (int i = 0; i < 4; i++)
                fuelLamps[i] = AddLamp(fu, FuelNames[i], 14 + i * 53, 32, 49, 40);
            fuelNote = MakeLabel(fu, "", 14, 84, Theme.Small, Theme.Dim, 210);
            fuelNote.Height = 32;

            var tr = AddCard("Trim wheel", L + 436, 324, 224, 124);
            trimCountLabel = MakeLabel(tr, "0", 10, 28, Theme.Big, Theme.Text, 70);
            trimCountLabel.Height = 34;
            MakeLabel(tr, "clicks", 82, 42, Theme.Small, Theme.Dim);
            new ToolTip().SetToolTip(trimCountLabel, "Trim clicks counted since connecting or Zero; + = nose down");
            var zero = new FlatBtn("Zero") { Left = 150, Top = 34, Width = 60, Height = 26, Font = Theme.Small };
            zero.Click += (s, e) => { trimZero = trimLast; UpdateTrimCount(); };
            tr.Controls.Add(zero);
            trimDnLamp = AddLamp(tr, "NOSE DN", 14, 76, 94, 34, Theme.Accent);
            trimUpLamp = AddLamp(tr, "NOSE UP", 116, 76, 94, 34, Theme.Accent);

            // ignition / buttons
            var ig = AddCard("Ignition key", L, 460, 290, 96);
            for (int i = 0; i < 5; i++)
                ignLamps[i] = AddLamp(ig, IgnNames[i], 14 + i * 53, 34, 49, 44,
                                      i == 4 ? Theme.Accent : Theme.Green);

            var bt = AddCard("Buttons Windows sees", L + 302, 460, 358, 96);
            var tips = new ToolTip();
            for (int i = 0; i < 14; i++)
            {
                int col = i % 7, row = i / 7;
                buttonLamps[i] = AddLamp(bt, (i + 1).ToString(), 14 + col * 47, 30 + row * 30, 42, 26, Theme.Blue);
                tips.SetToolTip(buttonLamps[i], $"Button {i + 1}: {ButtonTips[i]}");
            }

            // wiring
            var wi = AddCard("Wiring check   ·   lit = pin is connected to GND", L, 568, W, 158);
            for (int i = 0; i < 12; i++)
            {
                int col = i % 6, row = i / 6;
                pinLamps[i] = AddLamp(wi, PinNames[i], 14 + col * 106, 34 + row * 40, 100, 32, Theme.Green);
                pinLamps[i].Font = Theme.Small;
            }
            MakeLabel(wi, "Flip each switch: nothing lights = check its GND wire; the wrong pin lights = wires swapped.",
                      14, 120, Theme.Small, Theme.Dim, W - 28).Height = 22;
        }

        Lamp AddLamp(Control parent, string text, int x, int y, int w, int h, Color? on = null)
        {
            var l = new Lamp(text) { Left = x, Top = y, Width = w, Height = h };
            if (on.HasValue) l.OnColor = on.Value;
            parent.Controls.Add(l);
            return l;
        }

        CheckBox AddCheck(Control parent, string text, int x, int y, string setName)
        {
            var c = new CheckBox
            {
                Text = text, Left = x, Top = y, AutoSize = true, FlatStyle = FlatStyle.Flat,
                ForeColor = Theme.Text, BackColor = Theme.Card, Font = Theme.Body,
            };
            c.FlatAppearance.BorderColor = Theme.Dim;
            c.FlatAppearance.CheckedBackColor = Theme.Accent;
            c.CheckedChanged += (s, e) => Set(setName, c.Checked ? 1 : 0);
            parent.Controls.Add(c);
            return c;
        }

        NumericUpDown AddNumber(Control parent, int x, int y, int w, int min, int max, Action<int> changed)
        {
            var n = new NumericUpDown
            {
                Left = x, Top = y, Width = w, Minimum = min, Maximum = max,
                BackColor = Theme.Input, ForeColor = Theme.Text, BorderStyle = BorderStyle.FixedSingle,
                TextAlign = HorizontalAlignment.Right,
            };
            n.ValueChanged += (s, e) => { if (!loading) changed((int)n.Value); };
            parent.Controls.Add(n);
            return n;
        }

        void BuildSetup()
        {
            const int X = 688, W = 376;

            var dir = AddCard("Direction", X, 64, W, 130);
            revThr  = AddCheck(dir, "Reverse throttle", 16, 32, "REV_THR");
            revMix  = AddCheck(dir, "Reverse mixture", 16, 58, "REV_MIX");
            revProp = AddCheck(dir, "Reverse prop", 16, 84, "REV_PROP");
            revTrim = AddCheck(dir, "Reverse trim wheel", 190, 32, "REV_TRIM");
            keyBtn = new FlatBtn("Key positions…") { Left = 190, Top = 54, Width = 160, Height = 30 };
            keyBtn.Click += (s, e) => EditKeyPositions();
            dir.Controls.Add(keyBtn);
            new ToolTip().SetToolTip(keyBtn, "Set which pin each ignition key position is wired to");
            MakeLabel(dir, "Changes work right away; Save keeps them.", 16, 108, Theme.Small, Theme.Dim);

            var fu = AddCard("Fuel selector", X, 206, W, 74);
            fuelToggle = AddCheck(fu, "ON-OFF-ON toggle stand-in (centre reads BOTH)", 16, 34, "FUEL_TOGGLE");

            var tr = AddCard("Trim wheel and brake pulses", X, 292, W, 92);
            MakeLabel(tr, "Encoder steps per click", 16, 36, Theme.Body, Theme.Text);
            trimSteps = AddNumber(tr, 290, 33, 70, 1, 8, v => Set("TRIM_STEPS", v));
            MakeLabel(tr, "Pulse length (ms)", 16, 64, Theme.Body, Theme.Text);
            pulseMs = AddNumber(tr, 290, 61, 70, 10, 250, v => Set("PULSE_MS", v));

            var cal = AddCard("Lever ranges", X, 396, W, 238);
            autoCal = AddCheck(cal, "Learn ranges by themselves as the levers move", 16, 32, "AUTO_CAL");
            MakeLabel(cal, "Low", 140, 60, Theme.Small, Theme.Dim);
            MakeLabel(cal, "High", 232, 60, Theme.Small, Theme.Dim);
            string[] names = { "Throttle", "Mixture", "Prop" };
            for (int i = 0; i < 3; i++)
            {
                int k = i;
                MakeLabel(cal, names[i], 16, 82 + i * 28, Theme.Body, Theme.Text);
                loBox[i] = AddNumber(cal, 140, 79 + i * 28, 80, 0, 1023, v => Set("LO" + k, v));
                hiBox[i] = AddNumber(cal, 232, 79 + i * 28, 80, 0, 1023, v => Set("HI" + k, v));
            }
            calBtn = new FlatBtn("Calibrate levers") { Left = 16, Top = 168, Width = 160, Height = 28 };
            calBtn.Click += (s, e) => { if (calibrating) FinishCalibration(); else StartCalibration(); };
            cal.Controls.Add(calBtn);
            calCancelBtn = new FlatBtn("Cancel") { Left = 184, Top = 168, Width = 80, Height = 28, Visible = false };
            calCancelBtn.Click += (s, e) => StopCalibration();
            cal.Controls.Add(calCancelBtn);
            calHint = MakeLabel(cal, "Move each lever all the way in and out, then click the button again.",
                                16, 202, Theme.Small, Theme.Dim, W - 32);
            calHint.Height = 30;
            calHint.Visible = false;

            saveBtn = new FlatBtn("Save to panel", primary: true) { Left = X, Top = 648, Width = 140, Height = 32 };
            saveBtn.Click += (s, e) => Save();
            Controls.Add(saveBtn);
            undoBtn = new FlatBtn("Undo changes") { Left = X + 148, Top = 648, Width = 120, Height = 32 };
            undoBtn.Click += (s, e) => { link.Send("LOAD"); link.Send("GET"); SetDirty(false); };
            Controls.Add(undoBtn);
            defaultsBtn = new FlatBtn("Defaults") { Left = X + 276, Top = 648, Width = 100, Height = 32 };
            defaultsBtn.Click += (s, e) => { link.Send("DEFAULTS"); link.Send("GET"); SetDirty(true); };
            Controls.Add(defaultsBtn);
            var tips = new ToolTip();
            tips.SetToolTip(undoBtn, "Go back to what's saved on the panel");
            tips.SetToolTip(defaultsBtn, "Go back to the settings at the top of test_panel.ino (lever ranges stay). Save to keep.");

            dirtyLabel = MakeLabel(this, "", X, 692, Theme.Small, Theme.Accent, W);
            dirtyLabel.Height = 22;
        }

        void BuildSim()
        {
            var c = AddCard("Microsoft Flight Simulator", 16, 738, 1048, 66);
            simOn = new CheckBox
            {
                Text = "Send the panel to MSFS", Left = 16, Top = 34, AutoSize = true, FlatStyle = FlatStyle.Flat,
                ForeColor = Theme.Text, BackColor = Theme.Card, Font = Theme.Bold,
            };
            simOn.FlatAppearance.CheckedBackColor = Theme.Accent;
            simOn.Checked = Settings.Get("sim", "1") == "1";
            sim.Enabled = simOn.Checked;
            simOn.CheckedChanged += (s, e) => { sim.Enabled = simOn.Checked; Settings.Set("sim", simOn.Checked ? "1" : "0"); };
            c.Controls.Add(simOn);

            simStatus = MakeLabel(c, "", 230, 26, Theme.Body, Theme.Dim, 500);
            simStatus.Height = 20;
            simLast = MakeLabel(c, "", 230, 44, Theme.Small, Theme.Dim, 500);
            simLast.Height = 18;

            var sync = new FlatBtn("Sync now") { Left = 748, Top = 26, Width = 90, Height = 30 };
            sync.Click += (s, e) => sim.ResyncSoon();
            c.Controls.Add(sync);
            var edit = new FlatBtn("Edit mapping") { Left = 846, Top = 26, Width = 104, Height = 30 };
            edit.Click += (s, e) => OpenFile(SimBridge.MapPath);
            c.Controls.Add(edit);
            var evs = new FlatBtn("Events") { Left = 958, Top = 26, Width = 76, Height = 30 };
            evs.Click += (s, e) => OpenFile(SimBridge.EventsPath);
            c.Controls.Add(evs);
            var tips = new ToolTip();
            tips.SetToolTip(sync, "Send every switch and lever to the sim again");
            tips.SetToolTip(edit, "What each control sends (sim-map.txt). Saved changes apply straight away.");
            tips.SetToolTip(evs, "Every input event the loaded aircraft has (input-events.txt)");
            tips.SetToolTip(simOn, "No bindings needed in MSFS. Clear any MSFS bindings for this panel's joystick so nothing happens twice.");
        }

        void OpenFile(string path)
        {
            try
            {
                if (!System.IO.File.Exists(path))
                {
                    if (path == SimBridge.MapPath) { System.IO.Directory.CreateDirectory(Log.Folder); System.IO.File.WriteAllText(path, SimBridge.DefaultMap); }
                    else { MessageBox.Show(this, "Load an aircraft in MSFS first: the list is written when it loads.", "C172 Test Panel"); return; }
                }
                System.Diagnostics.Process.Start("notepad.exe", "\"" + path + "\"");
            }
            catch (Exception ex) { MessageBox.Show(this, ex.Message, "C172 Test Panel"); }
        }

        void UpdateSimStatus()
        {
            string text; Color color;
            if (!sim.Enabled) { text = "Off: bind the panel's joystick in MSFS instead."; color = Theme.Dim; }
            else if (sim.Problem.Length > 0) { text = sim.Problem; color = Theme.Red; }
            else if (!sim.Connected) { text = "Waiting for MSFS to start…"; color = Theme.Dim; }
            else
            {
                text = "● Connected to MSFS" + (sim.Aircraft.Length > 0 ? "   ·   " + sim.Aircraft : "") +
                       (sim.InputEventCount > 0 ? $"   ·   {sim.InputEventCount} input events" : "");
                if (last == null) text += "   ·   panel not connected";
                color = last == null ? Theme.Accent : Theme.Green;
            }
            if (simStatus.Text != text) simStatus.Text = text;
            simStatus.ForeColor = color;
            string ls = sim.LastSent.Length > 0 ? "Last sent   " + sim.LastSent : "";
            if (simLast.Text != ls) simLast.Text = ls;
        }

        // =====================================================================
        //  connection
        // =====================================================================

        void Rescan(bool autoConnect)
        {
            if (scanning) return;
            scanning = true;
            rescanBtn.Enabled = false;
            Status("Looking for the test panel…", Theme.Dim);
            string current = link.IsOpen ? link.PortName : null;

            new Thread(() =>
            {
                var ports = PanelLink.ListPorts();
                string found = null, version = null;
                if (autoConnect)
                {
                    // only ask Pro Micro / Leonardo-type boards, the one that worked last time first
                    string lastGood = Log.LastPort;
                    foreach (var p in ports.OrderByDescending(x => x.Name == lastGood))
                    {
                        if (p.Name == current || !p.LooksLikeBoard) continue;
                        version = PanelLink.Probe(p.Name);
                        if (version != null) { found = p.Name; break; }
                    }
                }
                try
                {
                    BeginInvoke((Action)(() =>
                    {
                        scanning = false;
                        rescanBtn.Enabled = true;
                        portBox.Items.Clear();
                        foreach (var p in ports) portBox.Items.Add(p);
                        string select = current ?? found ?? ports.FirstOrDefault(p => p.LooksLikeBoard)?.Name;
                        var item = ports.FirstOrDefault(p => p.Name == select) ?? ports.FirstOrDefault();
                        if (item != null) portBox.SelectedItem = item;

                        if (link.IsOpen) { UpdateStatus(); return; }
                        if (found != null) Connect(found);
                        else if (ports.Count == 0) Status("No COM ports. Plug the Pro Micro in, then Rescan.", Theme.Red);
                        else Status(autoConnect
                            ? "Test panel not found. Pick its port and Connect, or upload the latest sketch."
                            : "Pick the Pro Micro's port and Connect.", Theme.Dim);
                    }));
                }
                catch { }
            }) { IsBackground = true }.Start();
        }

        void ConnectSelected()
        {
            if (portBox.SelectedItem is PortInfo p) Connect(p.Name);
            else Status("Pick a port first.", Theme.Red);
        }

        void Connect(string name)
        {
            try
            {
                link.Open(name);
            }
            catch (UnauthorizedAccessException)
            {
                Status($"{name} is busy. Close the Arduino Serial Monitor or other apps using it.", Theme.Red);
                return;
            }
            catch (Exception ex)
            {
                Log.Write($"connect {name}: {ex.Message}");
                Status($"Couldn't open {name}: {ex.Message}", Theme.Red);
                return;
            }
            wantedPort = name;
            firmware = null;
            openedAt = DateTime.UtcNow;
            lastData = DateTime.MinValue;
            link.Send("HELLO");
            link.Send("STREAM 1");
            link.Send("GET");
            SetConnectedUi(true);
            UpdateStatus();
        }

        void Disconnect()
        {
            wantedPort = null;
            link.Close();
            StopCalibration();
            SetConnectedUi(false);
            ClearLive();
            Status("Disconnected.", Theme.Dim);
        }

        void OnLost()
        {
            link.Close();
            SetConnectedUi(false);
            ClearLive();
            if (wantedPort != null) Status($"Unplugged. Waiting for {wantedPort} to come back…", Theme.Accent);
        }

        void OnTick()
        {
            // come back after an unplug / re-upload
            if (!link.IsOpen && wantedPort != null && !scanning)
            {
                if ((DateTime.UtcNow - lastRetry).TotalSeconds < 3) return;
                lastRetry = DateTime.UtcNow;
                if (System.IO.Ports.SerialPort.GetPortNames().Contains(wantedPort))
                {
                    try { Connect(wantedPort); } catch { }
                }
                return;
            }
            if (!link.IsOpen) return;

            link.Send("GET");
            if (firmware == null && (DateTime.UtcNow - openedAt).TotalSeconds > 2) link.Send("HELLO");
            UpdateStatus();
        }

        void UpdateStatus()
        {
            if (!link.IsOpen) return;
            double since = (DateTime.UtcNow - openedAt).TotalSeconds;
            if (firmware == null)
            {
                if (since > 3)
                    Status($"{link.PortName} doesn't answer. Upload the latest test_panel.ino to the Pro Micro.", Theme.Red);
                else Status($"Connecting to {link.PortName}…", Theme.Dim);
            }
            else if ((DateTime.UtcNow - lastData).TotalSeconds > 2)
                Status($"{link.PortName} · firmware v{firmware} · waiting for data…", Theme.Accent);
            else
                Status($"● Connected   {link.PortName} · firmware v{firmware}", Theme.Green);
        }

        void Status(string text, Color color)
        {
            statusLabel.Text = text;
            statusLabel.ForeColor = color;
        }

        void SetConnectedUi(bool on)
        {
            connectBtn.Text = on || wantedPort != null ? "Disconnect" : "Connect";
            portBox.Enabled = !on && wantedPort == null;
            foreach (Control c in new Control[] { revThr, revMix, revProp, revTrim, keyBtn, fuelToggle, autoCal,
                                                  trimSteps, pulseMs, calBtn, saveBtn, undoBtn, defaultsBtn })
                c.Enabled = on;
            foreach (var n in loBox.Concat(hiBox)) n.Enabled = on;
        }

        // =====================================================================
        //  data from the panel
        // =====================================================================

        void OnLine(string line)
        {
            if (line.StartsWith("D,"))
            {
                var d = PanelLink.ParseData(line);
                if (d == null) return;
                bool first = (DateTime.UtcNow - lastData).TotalSeconds > 2;
                lastData = DateTime.UtcNow;
                ShowLive(d);
                if (first) UpdateStatus();
            }
            else if (line.StartsWith("CFG,"))
            {
                var c = PanelLink.ParseConfig(line);
                if (c != null) ShowConfig(c);
            }
            else if (line.StartsWith("C172TP,"))
            {
                firmware = line.Substring(7);
                Log.LastPort = link.PortName;
                Log.Write($"{link.PortName}: test panel firmware v{firmware}");
                UpdateStatus();
            }
            else if (line == "ERR")
            {
                Status("The panel didn't understand a setting. Upload the latest test_panel.ino.", Theme.Red);
            }
        }

        void ShowLive(LiveData d)
        {
            last = d;
            sim.Update(d);
            for (int i = 0; i < 3; i++)
            {
                levers[i].Raw = d.Raw[i];
                levers[i].Out = d.Out[i];
                if (calibrating)
                {
                    capLo[i] = Math.Min(capLo[i], d.Raw[i]);
                    capHi[i] = Math.Max(capHi[i], d.Raw[i]);
                    levers[i].CapLo = capLo[i];
                    levers[i].CapHi = capHi[i];
                }
                levers[i].Invalidate();
            }

            bool Btn(int i) => (d.Buttons & (1 << i)) != 0;
            for (int i = 0; i < 14; i++) buttonLamps[i].On = Btn(i);
            for (int i = 0; i < 12; i++) pinLamps[i].On = (d.Pins & (1 << i)) != 0;
            keyDialog?.UpdatePins(d.Pins);

            brakeLamp.On = Btn(0);
            brakeLamp.Text = Btn(0) ? "SET" : "RELEASED";
            brakeLamp.Invalidate();
            brakeSetLamp.On = Btn(1);
            brakeRelLamp.On = Btn(2);

            for (int i = 0; i < 4; i++) fuelLamps[i].On = Btn(3 + i);
            int fuelCount = Enumerable.Range(3, 4).Count(Btn);
            if (config != null && config.FuelToggle) fuelNote.Text = "Toggle mode: centre = BOTH, no OFF.";
            else if (fuelCount == 0) fuelNote.Text = "No position: between detents, or check the wiring.";
            else if (fuelCount > 1) fuelNote.Text = "More than one position on: check the wiring.";
            else fuelNote.Text = "";
            fuelNote.ForeColor = fuelCount == 1 || (config?.FuelToggle ?? false) ? Theme.Dim : Theme.Accent;

            trimDnLamp.On = Btn(7);
            trimUpLamp.On = Btn(8);
            trimLast = d.Trim;
            UpdateTrimCount();

            for (int i = 0; i < 5; i++) ignLamps[i].On = Btn(9 + i);
        }

        void UpdateTrimCount()
        {
            long n = trimLast - trimZero;
            trimCountLabel.Text = n > 0 ? "+" + n : n.ToString();
        }

        void ClearLive()
        {
            last = null;
            sim.Update(null);
            foreach (var l in levers) { l.Raw = l.Out = -1; l.Invalidate(); }
            foreach (var l in buttonLamps.Concat(pinLamps).Concat(fuelLamps).Concat(ignLamps)) l.On = false;
            brakeLamp.On = brakeSetLamp.On = brakeRelLamp.On = trimDnLamp.On = trimUpLamp.On = false;
            brakeLamp.Text = "—";
            brakeLamp.Invalidate();
            fuelNote.Text = "";
        }

        void ShowConfig(PanelConfig c)
        {
            config = c;
            loading = true;
            try
            {
                SetCheck(revThr, c.RevThr); SetCheck(revMix, c.RevMix); SetCheck(revProp, c.RevProp);
                SetCheck(revTrim, c.RevTrim);
                SetCheck(fuelToggle, c.FuelToggle); SetCheck(autoCal, c.AutoCal);
                SetNumber(trimSteps, c.TrimSteps);
                SetNumber(pulseMs, c.PulseMs);
                for (int i = 0; i < 3; i++)
                {
                    SetNumber(loBox[i], c.Lo[i]);
                    SetNumber(hiBox[i], c.Hi[i]);
                    levers[i].Lo = c.Lo[i];
                    levers[i].Hi = c.Hi[i];
                    levers[i].Invalidate();
                }
                levers[0].Reversed = c.RevThr; levers[1].Reversed = c.RevMix; levers[2].Reversed = c.RevProp;
            }
            finally { loading = false; }
        }

        // don't overwrite a box the user is typing in
        void SetCheck(CheckBox b, bool v) { if (!b.Focused && b.Checked != v) b.Checked = v; }
        void SetNumber(NumericUpDown n, int v)
        {
            if (n.ContainsFocus) return;
            v = Math.Max((int)n.Minimum, Math.Min((int)n.Maximum, v));
            if (n.Value != v) n.Value = v;
        }

        // =====================================================================
        //  settings
        // =====================================================================

        void Set(string name, int value)
        {
            if (loading || !link.IsOpen) return;
            link.Send($"SET {name} {value}");
            link.Send("GET");
            SetDirty(true);
        }

        void Save()
        {
            if (!link.IsOpen) return;
            link.Send("SAVE");
            link.Send("GET");
            SetDirty(false);
            Status($"● Saved to the panel   {link.PortName} · firmware v{firmware}", Theme.Green);
        }

        void SetDirty(bool on)
        {
            dirty = on;
            dirtyLabel.Text = on ? "Not saved yet: the panel forgets these when unplugged." : "";
        }

        void EditKeyPositions()
        {
            if (!link.IsOpen) return;
            if (config == null || config.IgnMap == null)
            {
                MessageBox.Show(this, "Upload the latest test_panel.ino (firmware v3) to set the key positions.",
                                "C172 Test Panel", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            // the old "reverse ignition" setting is folded into the map
            int[] current = config.IgnMap;
            if (config.RevIgn) current = current.Reverse().ToArray();
            using (keyDialog = new KeyMapDialog(current))
            {
                if (last != null) keyDialog.UpdatePins(last.Pins);
                var r = keyDialog.ShowDialog(this);
                var map = keyDialog.Map;
                keyDialog = null;
                if (r != DialogResult.OK || !link.IsOpen) return;
                link.Send("SET REV_IGN 0");
                for (int i = 0; i < 5; i++) link.Send($"SET IGN{i} {map[i]}");
                link.Send("GET");
                SetDirty(true);
            }
        }

        void StartCalibration()
        {
            if (!link.IsOpen) return;
            calibrating = true;
            for (int i = 0; i < 3; i++) { capLo[i] = 1023; capHi[i] = 0; }
            calBtn.Text = "Use these ranges";
            calBtn.BackColor = Theme.Green;
            calBtn.ForeColor = Theme.Back;
            calCancelBtn.Visible = true;
            calHint.Visible = true;
        }

        void FinishCalibration()
        {
            var skipped = new List<string>();
            string[] names = { "throttle", "mixture", "prop" };
            for (int i = 0; i < 3; i++)
            {
                if (capHi[i] - capLo[i] < 150) { skipped.Add(names[i]); continue; }
                link.Send($"SET LO{i} {capLo[i]}");
                link.Send($"SET HI{i} {capHi[i]}");
            }
            link.Send("GET");
            StopCalibration();
            if (skipped.Count < 3) SetDirty(true);
            if (skipped.Count > 0)
                Status($"Kept the old range for {string.Join(", ", skipped)} (it barely moved).", Theme.Accent);
        }

        void StopCalibration()
        {
            calibrating = false;
            calBtn.Text = "Calibrate levers";
            calBtn.BackColor = Theme.Input;
            calBtn.ForeColor = Theme.Text;
            calCancelBtn.Visible = false;
            calHint.Visible = false;
            foreach (var l in levers) { l.CapLo = l.CapHi = -1; l.Invalidate(); }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (dirty && link.IsOpen)
            {
                var r = MessageBox.Show(this,
                    "Save your changes to the panel?\n\nIf you don't, it goes back to its saved settings when it's unplugged.",
                    "C172 Test Panel", MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question);
                if (r == DialogResult.Cancel) { e.Cancel = true; return; }
                if (r == DialogResult.Yes) link.Send("SAVE");
                else link.Send("LOAD");
                Thread.Sleep(100);
            }
            tick.Stop();
            simTick.Stop();
            sim.Dispose();
            link.Close();
            base.OnFormClosing(e);
        }
    }
}
