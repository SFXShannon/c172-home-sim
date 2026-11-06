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
            Application.Run(new MainForm());
        }
    }
}
