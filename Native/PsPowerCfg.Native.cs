// PsPowerCfg native interop layer.
//
// Compiled at module import by Add-Type under BOTH Windows PowerShell 5.1
// (.NET Framework csc, C# 5) and PowerShell 7 (Roslyn, .NET 8+).
// Rules: C# 5 syntax only (no string interpolation, no out var, no
// expression-bodied members, no nameof, no auto-property initializers), and
// only types that exist in both runtimes.

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace PsPowerCfg
{
    public enum PowerDataAccessor : uint
    {
        Scheme = 16,            // ACCESS_SCHEME
        Subgroup = 17,          // ACCESS_SUBGROUP
        IndividualSetting = 18  // ACCESS_INDIVIDUAL_SETTING
    }

    public sealed class PowerScheme
    {
        public Guid Guid { get; private set; }
        public string Name { get; private set; }
        public string Description { get; private set; }
        public bool IsActive { get; private set; }

        internal PowerScheme(Guid guid, string name, string description, bool isActive)
        {
            Guid = guid;
            Name = name;
            Description = description;
            IsActive = isActive;
        }

        public override string ToString()
        {
            return Name;
        }
    }

    internal static class NativeMethods
    {
        internal const uint ERROR_SUCCESS = 0;
        internal const uint ERROR_FILE_NOT_FOUND = 2;
        internal const uint ERROR_MORE_DATA = 234;
        internal const uint ERROR_NO_MORE_ITEMS = 259;

        // const GUID* parameters are declared as Guid[]: a null array marshals
        // to NULL, a one-element array marshals to a pointer to the GUID.

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerEnumerate(
            IntPtr rootPowerKey,
            Guid[] schemeGuid,
            Guid[] subGroupOfPowerSettingsGuid,
            uint accessFlags,
            uint index,
            ref Guid buffer,
            ref uint bufferSize);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadFriendlyName(
            IntPtr rootPowerKey,
            Guid[] schemeGuid,
            Guid[] subGroupOfPowerSettingsGuid,
            Guid[] powerSettingGuid,
            byte[] buffer,
            ref uint bufferSize);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadDescription(
            IntPtr rootPowerKey,
            Guid[] schemeGuid,
            Guid[] subGroupOfPowerSettingsGuid,
            Guid[] powerSettingGuid,
            byte[] buffer,
            ref uint bufferSize);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerGetActiveScheme(
            IntPtr userRootPowerKey,
            out IntPtr activePolicyGuid);

        [DllImport("kernel32.dll", ExactSpelling = true)]
        internal static extern IntPtr LocalFree(IntPtr hMem);
    }

    internal delegate uint PowerReadStringFn(
        IntPtr root, Guid[] scheme, Guid[] sub, Guid[] setting, byte[] buffer, ref uint size);

    public static class PowerApi
    {
        private static Guid[] Wrap(Guid? g)
        {
            return g.HasValue ? new Guid[] { g.Value } : null;
        }

        internal static Win32Exception Fail(string api, uint rc)
        {
            return new Win32Exception((int)rc, api + " failed (0x" + rc.ToString("X8") + "): " + new Win32Exception((int)rc).Message);
        }

        public static Guid[] Enumerate(Guid? scheme, Guid? subgroup, PowerDataAccessor accessor)
        {
            Guid[] s = Wrap(scheme);
            Guid[] sg = Wrap(subgroup);
            List<Guid> list = new List<Guid>();
            uint index = 0;
            while (true)
            {
                Guid g = Guid.Empty;
                uint size = 16;
                uint rc = NativeMethods.PowerEnumerate(IntPtr.Zero, s, sg, (uint)accessor, index, ref g, ref size);
                if (rc == NativeMethods.ERROR_NO_MORE_ITEMS) { break; }
                if (rc != NativeMethods.ERROR_SUCCESS) { throw Fail("PowerEnumerate", rc); }
                list.Add(g);
                index++;
            }
            return list.ToArray();
        }

        public static Guid[] EnumerateSchemes()
        {
            return Enumerate(null, null, PowerDataAccessor.Scheme);
        }

        public static Guid GetActiveScheme()
        {
            IntPtr p;
            uint rc = NativeMethods.PowerGetActiveScheme(IntPtr.Zero, out p);
            if (rc != NativeMethods.ERROR_SUCCESS) { throw Fail("PowerGetActiveScheme", rc); }
            try
            {
                return (Guid)Marshal.PtrToStructure(p, typeof(Guid));
            }
            finally
            {
                NativeMethods.LocalFree(p);
            }
        }

        private static string ReadString(PowerReadStringFn fn, string api, Guid? scheme, Guid? subgroup, Guid? setting)
        {
            Guid[] s = Wrap(scheme);
            Guid[] sg = Wrap(subgroup);
            Guid[] st = Wrap(setting);
            uint size = 0;
            uint rc = fn(IntPtr.Zero, s, sg, st, null, ref size);
            if (rc == NativeMethods.ERROR_FILE_NOT_FOUND) { return null; }
            if (rc != NativeMethods.ERROR_SUCCESS && rc != NativeMethods.ERROR_MORE_DATA) { throw Fail(api, rc); }
            if (size == 0) { return string.Empty; }

            byte[] buffer = new byte[size];
            rc = fn(IntPtr.Zero, s, sg, st, buffer, ref size);
            if (rc != NativeMethods.ERROR_SUCCESS) { throw Fail(api, rc); }

            // UTF-16LE, null terminated.
            int chars = (int)size / 2;
            string value = Encoding.Unicode.GetString(buffer, 0, chars * 2);
            int nul = value.IndexOf('\0');
            return nul >= 0 ? value.Substring(0, nul) : value;
        }

        public static string ReadFriendlyName(Guid? scheme, Guid? subgroup, Guid? setting)
        {
            return ReadString(NativeMethods.PowerReadFriendlyName, "PowerReadFriendlyName", scheme, subgroup, setting);
        }

        public static string ReadDescription(Guid? scheme, Guid? subgroup, Guid? setting)
        {
            return ReadString(NativeMethods.PowerReadDescription, "PowerReadDescription", scheme, subgroup, setting);
        }

        public static PowerScheme GetScheme(Guid scheme, Guid activeScheme)
        {
            return new PowerScheme(
                scheme,
                ReadFriendlyName(scheme, null, null),
                ReadDescription(scheme, null, null),
                scheme == activeScheme);
        }

        public static PowerScheme[] GetSchemes()
        {
            Guid active = GetActiveScheme();
            Guid[] guids = EnumerateSchemes();
            PowerScheme[] result = new PowerScheme[guids.Length];
            for (int i = 0; i < guids.Length; i++)
            {
                result[i] = GetScheme(guids[i], active);
            }
            return result;
        }

        public static PowerScheme GetActivePowerScheme()
        {
            Guid active = GetActiveScheme();
            return GetScheme(active, active);
        }
    }
}
