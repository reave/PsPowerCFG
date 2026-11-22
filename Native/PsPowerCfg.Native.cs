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

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerSetActiveScheme(IntPtr userRootPowerKey, Guid[] schemeGuid);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerDuplicateScheme(
            IntPtr rootPowerKey,
            Guid[] sourceSchemeGuid,
            ref IntPtr destinationSchemeGuid);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerDeleteScheme(IntPtr rootPowerKey, Guid[] schemeGuid);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerWriteFriendlyName(
            IntPtr rootPowerKey,
            Guid[] schemeGuid,
            Guid[] subGroupOfPowerSettingsGuid,
            Guid[] powerSettingGuid,
            byte[] buffer,
            uint bufferSize);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerWriteDescription(
            IntPtr rootPowerKey,
            Guid[] schemeGuid,
            Guid[] subGroupOfPowerSettingsGuid,
            Guid[] powerSettingGuid,
            byte[] buffer,
            uint bufferSize);

        [DllImport("powrprof.dll", ExactSpelling = true, CharSet = CharSet.Unicode)]
        internal static extern uint PowerImportPowerScheme(
            IntPtr rootPowerKey,
            string importFileNamePath,
            ref IntPtr destinationSchemeGuid);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerRestoreDefaultPowerSchemes();

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerRestoreIndividualDefaultPowerScheme(Guid[] schemeGuid);

        [DllImport("kernel32.dll", ExactSpelling = true)]
        internal static extern IntPtr LocalFree(IntPtr hMem);
    }

    internal delegate uint PowerReadStringFn(
        IntPtr root, Guid[] scheme, Guid[] sub, Guid[] setting, byte[] buffer, ref uint size);

    internal delegate uint PowerWriteStringFn(
        IntPtr root, Guid[] scheme, Guid[] sub, Guid[] setting, byte[] buffer, uint size);

    internal delegate uint GuidOutFn(ref IntPtr destination);

    public static class PowerApi
    {
        // Set by the module loader to the hash of the source this assembly was
        // built from, so a re-import after an upgrade can detect that an older
        // build is still loaded (a loaded .NET type cannot be replaced).
        public static string LoadedSourceHash;

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

        private static void Check(string api, uint rc)
        {
            if (rc != NativeMethods.ERROR_SUCCESS) { throw Fail(api, rc); }
        }

        // For APIs that take GUID** and either fill a caller-supplied GUID or
        // LocalAlloc a new one when *ptr is NULL.
        private static Guid InvokeGuidOut(string api, Guid? requested, GuidOutFn fn)
        {
            IntPtr mine = IntPtr.Zero;
            if (requested.HasValue)
            {
                mine = Marshal.AllocHGlobal(16);
                Marshal.StructureToPtr(requested.Value, mine, false);
            }
            IntPtr p = mine;
            try
            {
                Check(api, fn(ref p));
                return (Guid)Marshal.PtrToStructure(p, typeof(Guid));
            }
            finally
            {
                if (p != IntPtr.Zero && p != mine) { NativeMethods.LocalFree(p); }
                if (mine != IntPtr.Zero) { Marshal.FreeHGlobal(mine); }
            }
        }

        private static void WriteString(PowerWriteStringFn fn, string api, Guid? scheme, Guid? subgroup, Guid? setting, string value)
        {
            if (value == null) { throw new ArgumentNullException("value"); }
            byte[] buffer = Encoding.Unicode.GetBytes(value + "\0");
            Check(api, fn(IntPtr.Zero, Wrap(scheme), Wrap(subgroup), Wrap(setting), buffer, (uint)buffer.Length));
        }

        public static void WriteFriendlyName(Guid? scheme, Guid? subgroup, Guid? setting, string value)
        {
            WriteString(NativeMethods.PowerWriteFriendlyName, "PowerWriteFriendlyName", scheme, subgroup, setting, value);
        }

        public static void WriteDescription(Guid? scheme, Guid? subgroup, Guid? setting, string value)
        {
            WriteString(NativeMethods.PowerWriteDescription, "PowerWriteDescription", scheme, subgroup, setting, value);
        }

        public static void SetActiveScheme(Guid scheme)
        {
            Check("PowerSetActiveScheme", NativeMethods.PowerSetActiveScheme(IntPtr.Zero, new Guid[] { scheme }));
        }

        public static Guid DuplicateScheme(Guid source, Guid? destination)
        {
            Guid[] src = new Guid[] { source };
            return InvokeGuidOut("PowerDuplicateScheme", destination,
                (ref IntPtr d) => NativeMethods.PowerDuplicateScheme(IntPtr.Zero, src, ref d));
        }

        public static void DeleteScheme(Guid scheme)
        {
            Check("PowerDeleteScheme", NativeMethods.PowerDeleteScheme(IntPtr.Zero, new Guid[] { scheme }));
        }

        public static Guid ImportScheme(string path, Guid? destination)
        {
            return InvokeGuidOut("PowerImportPowerScheme", destination,
                (ref IntPtr d) => NativeMethods.PowerImportPowerScheme(IntPtr.Zero, path, ref d));
        }

        public static void RestoreDefaultSchemes()
        {
            Check("PowerRestoreDefaultPowerSchemes", NativeMethods.PowerRestoreDefaultPowerSchemes());
        }

        public static void RestoreDefaultScheme(Guid scheme)
        {
            Check("PowerRestoreIndividualDefaultPowerScheme", NativeMethods.PowerRestoreIndividualDefaultPowerScheme(new Guid[] { scheme }));
        }

        public static PowerScheme GetScheme(Guid scheme)
        {
            return GetScheme(scheme, GetActiveScheme());
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
