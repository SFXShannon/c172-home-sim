using System;
using System.Runtime.InteropServices;

namespace C172TestPanel
{
    /// <summary>
    /// The handful of SimConnect calls the panel needs, straight from SimConnect.dll
    /// (the native DLL from the MSFS SDK, which works with MSFS 2020 and 2024).
    /// Layouts follow SimConnect.h, which packs its structs to 1 byte.
    /// </summary>
    static class SimConnectNative
    {
        const string Dll = "SimConnect.dll";

        [DllImport(Dll, CharSet = CharSet.Ansi)]
        public static extern int SimConnect_Open(out IntPtr handle, string name, IntPtr hWnd,
                                                 uint userEventWin32, IntPtr hEventHandle, uint configIndex);

        [DllImport(Dll)]
        public static extern int SimConnect_Close(IntPtr handle);

        [DllImport(Dll)]
        public static extern int SimConnect_GetNextDispatch(IntPtr handle, out IntPtr data, out uint size);

        [DllImport(Dll, CharSet = CharSet.Ansi)]
        public static extern int SimConnect_MapClientEventToSimEvent(IntPtr handle, uint eventId, string eventName);

        [DllImport(Dll)]
        public static extern int SimConnect_TransmitClientEvent(IntPtr handle, uint objectId, uint eventId,
                                                                uint data, uint groupId, uint flags);

        [DllImport(Dll, CharSet = CharSet.Ansi)]
        public static extern int SimConnect_SubscribeToSystemEvent(IntPtr handle, uint eventId, string systemEventName);

        [DllImport(Dll)]
        public static extern int SimConnect_EnumerateInputEvents(IntPtr handle, uint requestId);

        [DllImport(Dll)]
        public static extern int SimConnect_SetInputEvent(IntPtr handle, ulong hash, uint unitSize, ref double value);

        // SIMCONNECT_RECV_ID values (without the experimental PICK entry)
        public const int RECV_EXCEPTION = 1, RECV_OPEN = 2, RECV_QUIT = 3, RECV_EVENT = 4,
                         RECV_EVENT_FILENAME = 6, RECV_ENUMERATE_INPUT_EVENTS = 34;

        public const uint OBJECT_ID_USER = 0;
        public const uint GROUP_PRIORITY_HIGHEST = 1;
        public const uint EVENT_FLAG_GROUPID_IS_PRIORITY = 0x10;

        // record offsets
        public const int OffId = 8;                 // SIMCONNECT_RECV.dwID
        public const int OffException = 12;         // SIMCONNECT_RECV_EXCEPTION.dwException
        public const int OffEventId = 16;           // SIMCONNECT_RECV_EVENT.uEventID
        public const int OffFileName = 24;          // SIMCONNECT_RECV_EVENT_FILENAME.szFileName[260]
        public const int OffListSize = 16;          // SIMCONNECT_RECV_LIST_TEMPLATE.dwArraySize
        public const int OffListEntry = 20;         // dwEntryNumber
        public const int OffListOutOf = 24;         // dwOutOf
        public const int OffListData = 28;          // first SIMCONNECT_INPUT_EVENT_DESCRIPTOR
        public const int InputEventSize = 76;       // Name[64] + Hash (8) + eType (4)
    }
}
