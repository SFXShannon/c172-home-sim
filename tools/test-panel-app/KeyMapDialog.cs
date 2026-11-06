using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace C172TestPanel
{
    /// <summary>
    /// Sets which ignition pin each key position (OFF, R, L, BOTH, START) is on,
    /// by picking from a list or by turning the key through the positions.
    /// </summary>
    class KeyMapDialog : Form
    {
        public static readonly string[] Positions = { "OFF", "R", "L", "BOTH", "START" };
        public static readonly int[] Pins = { 9, 10, 14, 15, 16 };
        const int PinMaskShift = 7;          // ignition pins are bits 7-11 of the pin mask

        /// <summary>Result: PIN_IGN index (0-4) per position, or -1 for not wired.</summary>
        public int[] Map { get; } = new int[5];

        readonly ComboBox[] boxes = new ComboBox[5];
        readonly Lamp[] lamps = new Lamp[5];
        readonly Label[] arrows = new Label[5];
        Label liveLabel, warnLabel, learnLabel;
        FlatBtn learnBtn, okBtn;
        int pins;                            // latest pin mask from the panel
        int learnStep = -1;                  // -1 = not learning

        public KeyMapDialog(int[] current)
        {
            Text = "Ignition key positions";
            AutoScaleDimensions = new SizeF(96f, 96f);
            AutoScaleMode = AutoScaleMode.Dpi;
            BackColor = Theme.Card;
            ForeColor = Theme.Text;
            Font = Theme.Body;
            ClientSize = new Size(460, 400);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = MinimizeBox = false;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.CenterParent;

            for (int i = 0; i < 5; i++) Map[i] = current != null && i < current.Length ? current[i] : i;

            Lbl("Pick the pin each key position is wired to, or click Learn and turn the key " +
                "through its positions.", 18, 14, 424, 36, Theme.Body, Theme.Dim);

            Lbl("Key position", 18, 60, 120, 18, Theme.Small, Theme.Dim);
            Lbl("Wired to", 140, 60, 120, 18, Theme.Small, Theme.Dim);
            Lbl("Reads now", 300, 60, 120, 18, Theme.Small, Theme.Dim);

            for (int i = 0; i < 5; i++)
            {
                int y = 82 + i * 38;
                arrows[i] = Lbl("", 4, y + 4, 14, 20, Theme.Bold, Theme.Accent);
                Lbl(Positions[i], 18, y + 4, 110, 20, Theme.Bold, Theme.Text);
                var b = new ComboBox
                {
                    Left = 140, Top = y + 2, Width = 140, DropDownStyle = ComboBoxStyle.DropDownList,
                    FlatStyle = FlatStyle.Flat, BackColor = Theme.Input, ForeColor = Theme.Text,
                };
                foreach (int p in Pins) b.Items.Add($"pin {p}");
                b.Items.Add("not wired");
                b.SelectedIndex = Map[i] >= 0 && Map[i] < 5 ? Map[i] : 5;
                int k = i;
                b.SelectedIndexChanged += (s, e) => { Map[k] = b.SelectedIndex < 5 ? b.SelectedIndex : -1; Refresh2(); };
                Controls.Add(b);
                boxes[i] = b;
                lamps[i] = new Lamp(Positions[i]) { Left = 300, Top = y, Width = 140, Height = 30,
                                                     OnColor = i == 4 ? Theme.Accent : Theme.Green };
                Controls.Add(lamps[i]);
            }

            liveLabel = Lbl("", 18, 274, 424, 18, Theme.Small, Theme.Dim);
            warnLabel = Lbl("", 18, 294, 424, 18, Theme.Small, Theme.Accent);

            learnBtn = new FlatBtn("Learn") { Left = 18, Top = 320, Width = 110, Height = 30 };
            learnBtn.Click += (s, e) => LearnClick();
            Controls.Add(learnBtn);
            learnLabel = Lbl("", 136, 322, 306, 34, Theme.Small, Theme.Accent);

            okBtn = new FlatBtn("Use these", primary: true) { Left = 222, Top = 360, Width = 110, Height = 30 };
            okBtn.Click += (s, e) => { DialogResult = DialogResult.OK; Close(); };
            Controls.Add(okBtn);
            var cancel = new FlatBtn("Cancel") { Left = 340, Top = 360, Width = 102, Height = 30 };
            cancel.Click += (s, e) => { DialogResult = DialogResult.Cancel; Close(); };
            Controls.Add(cancel);
            AcceptButton = okBtn;
            CancelButton = cancel;

            Refresh2();
        }

        Label Lbl(string text, int x, int y, int w, int h, Font f, Color c)
        {
            var l = new Label { Text = text, Left = x, Top = y, Width = w, Height = h, Font = f,
                                ForeColor = c, BackColor = Theme.Card };
            Controls.Add(l);
            return l;
        }

        /// <summary>Called with each live data line while the dialog is open.</summary>
        public void UpdatePins(int pinMask)
        {
            pins = pinMask;
            if (learnStep >= 0) AutoLearn();
            Refresh2();
        }

        // While learning, take a position by itself once one new pin has been
        // connected to GND for a moment: no clicking while holding the key at START.
        int candidate = -1;
        DateTime candidateSince;
        readonly System.Collections.Generic.List<int> learned = new System.Collections.Generic.List<int>();

        void AutoLearn()
        {
            var low = Enumerable.Range(0, 5).Where(PinLow).ToList();
            int pin = low.Count == 1 && !learned.Contains(low[0]) ? low[0] : -1;
            if (pin != candidate) { candidate = pin; candidateSince = DateTime.UtcNow; return; }
            // the first position waits longer, so there's time to turn the key to OFF
            int hold = learnStep == 0 ? 1500 : 400;
            if (pin < 0 || (DateTime.UtcNow - candidateSince).TotalMilliseconds < hold) return;
            Take(pin);
        }

        void Take(int pin)
        {
            boxes[learnStep].SelectedIndex = pin;
            learned.Add(pin);
            candidate = -1;
            learnStep++;
            ShowLearnStep();
        }

        bool PinLow(int idx) => idx >= 0 && idx < 5 && (pins & (1 << (PinMaskShift + idx))) != 0;

        void Refresh2()
        {
            for (int i = 0; i < 5; i++)
            {
                lamps[i].On = PinLow(Map[i]);
                arrows[i].Text = i == learnStep ? "▸" : "";
            }

            var low = Enumerable.Range(0, 5).Where(PinLow).Select(i => Pins[i].ToString()).ToList();
            liveLabel.Text = low.Count == 0 ? "Key pins connected to GND now: none (between positions?)"
                                            : "Key pins connected to GND now: " + string.Join(", ", low);

            var dupes = Map.Where(m => m >= 0).GroupBy(m => m).Where(g => g.Count() > 1)
                           .Select(g => Pins[g.Key]).ToList();
            warnLabel.Text = dupes.Count > 0
                ? $"Pin {string.Join(", ", dupes)} is set for more than one position."
                : "";
        }

        void LearnClick()
        {
            if (learnStep < 0)
            {
                // start: the key is usually already at OFF, so wait for a fresh pin
                learned.Clear();
                candidate = -1;
                learnStep = 0;
                ShowLearnStep();
                return;
            }
            // "Not wired": skip this position
            boxes[learnStep].SelectedIndex = 5;
            learnStep++;
            ShowLearnStep();
        }

        void ShowLearnStep()
        {
            learnLabel.ForeColor = Theme.Accent;
            if (learnStep >= 5)
            {
                learnStep = -1;
                learnBtn.Text = "Learn";
                learnLabel.Text = "Done. Turn the key through again to check, then Use these.";
                learnLabel.ForeColor = Theme.Green;
            }
            else
            {
                learnBtn.Text = "Not wired";
                learnLabel.Text = learnStep == 4
                    ? "Turn the key to START and hold it a moment."
                    : $"Turn the key to {Positions[learnStep]}" +
                      (learnStep == 0 ? " and leave it there a moment." : ".");
            }
            Refresh2();
        }
    }
}
