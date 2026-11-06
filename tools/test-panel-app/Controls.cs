using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace C172TestPanel
{
    static class Theme
    {
        public static readonly Color Back    = Color.FromArgb(0x14, 0x17, 0x1C);
        public static readonly Color Card    = Color.FromArgb(0x1E, 0x23, 0x2A);
        public static readonly Color Border  = Color.FromArgb(0x2E, 0x35, 0x3F);
        public static readonly Color Track   = Color.FromArgb(0x2A, 0x30, 0x39);
        public static readonly Color Range   = Color.FromArgb(0x4A, 0x63, 0x7E);
        public static readonly Color Text    = Color.FromArgb(0xE6, 0xE9, 0xED);
        public static readonly Color Dim     = Color.FromArgb(0x8C, 0x96, 0xA3);
        public static readonly Color Accent  = Color.FromArgb(0xF2, 0xA3, 0x3A);   // amber
        public static readonly Color Green   = Color.FromArgb(0x4C, 0xC3, 0x8A);
        public static readonly Color Blue    = Color.FromArgb(0x4E, 0xA1, 0xFF);
        public static readonly Color Red     = Color.FromArgb(0xE5, 0x5B, 0x5B);
        public static readonly Color Input   = Color.FromArgb(0x26, 0x2C, 0x34);

        public static readonly Font Body  = new Font("Segoe UI", 9f);
        public static readonly Font Bold  = new Font("Segoe UI Semibold", 9.5f);
        public static readonly Font Small = new Font("Segoe UI", 8f);
        public static readonly Font Title = new Font("Segoe UI Semibold", 8.5f);
        public static readonly Font Big   = new Font("Segoe UI Semibold", 16f);

        public static GraphicsPath Round(RectangleF r, float radius)
        {
            var p = new GraphicsPath();
            float d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
            if (d <= 0.5f) { p.AddRectangle(r); return p; }
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        // How much the window has been scaled from its 96-dpi layout. Taken from the
        // window's real size so painting always matches the layout (DeviceDpi can
        // disagree with it on mixed-DPI setups).
        public static float UiScale = 1f;
        public static float Scale(Control c) => UiScale;
    }

    /// <summary>Rounded card with a small caps title. Children go below the title.</summary>
    class Card : Panel
    {
        public Card(string title)
        {
            Text = title;
            DoubleBuffered = true;
            BackColor = Theme.Back;
            ForeColor = Theme.Text;
            SetStyle(ControlStyles.ResizeRedraw, true);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            float s = Theme.Scale(this);
            var r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            using (var path = Theme.Round(r, 8 * s))
            using (var b = new SolidBrush(Theme.Card))
            using (var pen = new Pen(Theme.Border))
            {
                g.FillPath(b, path);
                g.DrawPath(pen, path);
            }
            TextRenderer.DrawText(g, Text.ToUpperInvariant(), Theme.Title,
                new Point((int)(12 * s), (int)(8 * s)), Theme.Dim);
        }
    }

    /// <summary>An indicator lamp with a label.</summary>
    class Lamp : Control
    {
        bool on;
        public Color OnColor = Theme.Green;

        public bool On
        {
            get => on;
            set { if (on != value) { on = value; Invalidate(); } }
        }

        public Lamp(string text)
        {
            Text = text;
            DoubleBuffered = true;
            SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.ResizeRedraw, true);
            BackColor = Theme.Card;
            Font = Theme.Body;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            float s = Theme.Scale(this);
            var r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            using (var path = Theme.Round(r, 5 * s))
            {
                using (var b = new SolidBrush(on ? OnColor : Theme.Track)) g.FillPath(b, path);
                using (var pen = new Pen(on ? OnColor : Theme.Border)) g.DrawPath(pen, path);
            }
            TextRenderer.DrawText(g, Text, Font, ClientRectangle,
                on ? Theme.Back : Theme.Dim,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter |
                TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding);
        }
    }

    /// <summary>
    /// One lever: the axis value Windows sees as a big bar, and under it the
    /// raw pot reading on a 0-1023 track with the calibrated range shaded.
    /// </summary>
    class LeverView : Control
    {
        public int Raw = -1, Out = -1, Lo = -1, Hi = -1;
        public int CapLo = -1, CapHi = -1;   // range caught by the calibration wizard
        public bool Reversed;

        public LeverView(string name)
        {
            Text = name;
            DoubleBuffered = true;
            SetStyle(ControlStyles.ResizeRedraw, true);
            BackColor = Theme.Card;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            float s = Theme.Scale(this);
            int w = Width;

            TextRenderer.DrawText(g, Text, Theme.Bold, new Point(0, 0), Theme.Text);
            int nameW = TextRenderer.MeasureText(Text, Theme.Bold).Width;
            string info = Raw < 0 ? "no data" :
                $"raw {Raw}   range {Lo}–{Hi}" + (Reversed ? "   reversed" : "");
            TextRenderer.DrawText(g, info, Theme.Small,
                new Point(nameW + (int)(8 * s), (int)(2 * s)), Theme.Dim);

            string pct = Out < 0 ? "—" : $"{Math.Round(Out * 100.0 / 1023)} %";
            var pctSize = TextRenderer.MeasureText(pct, Theme.Bold);
            TextRenderer.DrawText(g, pct, Theme.Bold, new Point(w - pctSize.Width, 0), Theme.Accent);

            // axis bar
            var bar = new RectangleF(0, 22 * s, w - 1, 16 * s);
            using (var path = Theme.Round(bar, 4 * s))
            using (var b = new SolidBrush(Theme.Track)) g.FillPath(b, path);
            if (Out > 0)
            {
                var fill = new RectangleF(bar.X, bar.Y, Math.Max(bar.Height, bar.Width * Out / 1023f), bar.Height);
                using (var path = Theme.Round(fill, 4 * s))
                using (var b = new SolidBrush(Theme.Accent)) g.FillPath(b, path);
            }

            // raw track
            float ty = 46 * s, th = 8 * s;
            var track = new RectangleF(0, ty, w - 1, th);
            using (var b = new SolidBrush(Theme.Track)) g.FillRectangle(b, track);
            float X(int v) => track.X + track.Width * Math.Max(0, Math.Min(1023, v)) / 1023f;
            if (Lo >= 0 && Hi > Lo)
                using (var b = new SolidBrush(Theme.Range))
                    g.FillRectangle(b, X(Lo), ty, X(Hi) - X(Lo), th);
            if (CapLo >= 0 && CapHi > CapLo)
                using (var pen = new Pen(Theme.Green, 2 * s))
                    g.DrawRectangle(pen, X(CapLo), ty - 2 * s, X(CapHi) - X(CapLo), th + 4 * s);
            if (Raw >= 0)
                using (var b = new SolidBrush(Theme.Text))
                    g.FillRectangle(b, X(Raw) - 1.5f * s, ty - 3 * s, 3 * s, th + 6 * s);
        }
    }

    /// <summary>Flat dark button.</summary>
    class FlatBtn : Button
    {
        public FlatBtn(string text, bool primary = false)
        {
            Text = text;
            FlatStyle = FlatStyle.Flat;
            Font = primary ? Theme.Bold : Theme.Body;
            BackColor = primary ? Theme.Accent : Theme.Input;
            ForeColor = primary ? Theme.Back : Theme.Text;
            FlatAppearance.BorderColor = primary ? Theme.Accent : Theme.Border;
            FlatAppearance.MouseOverBackColor = primary ? Color.FromArgb(0xFF, 0xB8, 0x5C) : Theme.Range;
            UseVisualStyleBackColor = false;
            Cursor = Cursors.Hand;
        }
    }
}
