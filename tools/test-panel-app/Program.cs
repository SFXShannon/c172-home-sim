using System;
using System.Windows.Forms;

namespace C172TestPanel
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            var args = Environment.GetCommandLineArgs();
            int shot = Array.IndexOf(args, "--screenshot");
            if (shot > 0 && shot + 1 < args.Length)
            {
                // Render the window with sample data to a PNG without showing it
                // (used for the README picture).
                using (var f = new MainForm(demo: true))
                {
                    f.SaveDemoScreenshot(args[shot + 1]);
                }
                return;
            }
            int keys = Array.IndexOf(args, "--screenshot-keys");
            if (keys > 0 && keys + 1 < args.Length)
            {
                using (var d = new KeyMapDialog(new[] { 0, 2, 1, 3, 4 }))
                {
                    d.StartPosition = FormStartPosition.Manual;
                    d.Location = new System.Drawing.Point(-20000, -20000);
                    d.Show();
                    d.UpdatePins(1 << 10);   // key at BOTH (pin 15)
                    Application.DoEvents();
                    using (var bmp = new System.Drawing.Bitmap(d.Width, d.Height))
                    {
                        d.DrawToBitmap(bmp, new System.Drawing.Rectangle(0, 0, d.Width, d.Height));
                        bmp.Save(args[keys + 1]);
                    }
                }
                return;
            }
            Application.Run(new MainForm());
        }
    }
}
