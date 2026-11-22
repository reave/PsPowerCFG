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

    public sealed class PowerSettingValue
    {
        public uint Index { get; private set; }
        public string Name { get; private set; }
        public string Description { get; private set; }

        internal PowerSettingValue(uint index, string name, string description)
        {
            Index = index;
            Name = name;
            Description = description;
        }

        public override string ToString()
        {
            return Index + ": " + Name;
        }
    }

    public sealed class PowerSetting
    {
        public Guid SchemeGuid { get; internal set; }
        public Guid SubgroupGuid { get; internal set; }
        public string SubgroupName { get; internal set; }
        public string SubgroupAlias { get; internal set; }
        public Guid Guid { get; internal set; }
        public string Name { get; internal set; }
        public string Alias { get; internal set; }
        public string Description { get; internal set; }
        public uint AcValue { get; internal set; }
        public uint DcValue { get; internal set; }
        public string AcValueName { get; internal set; }
        public string DcValueName { get; internal set; }
        // Range settings have Minimum/Maximum/Increment/Units; index settings
        // have PossibleValues. AcValue/DcValue are the raw index either way.
        public bool IsRange { get; internal set; }
        public uint? Minimum { get; internal set; }
        public uint? Maximum { get; internal set; }
        public uint? Increment { get; internal set; }
        public string Units { get; internal set; }
        public PowerSettingValue[] PossibleValues { get; internal set; }
        public uint Attributes { get; internal set; }
        public bool IsHidden { get { return (Attributes & 1) != 0; } }
        // True when Group Policy overrides the AC or DC value.
        public bool AcPolicyManaged { get; internal set; }
        public bool DcPolicyManaged { get; internal set; }

        public override string ToString()
        {
            return Name;
        }
    }

    public sealed class PowerAlias
    {
        public string Alias { get; private set; }
        public Guid Guid { get; private set; }
        public string Kind { get; private set; }
        public Guid? SubgroupGuid { get; private set; }

        internal PowerAlias(string alias, Guid guid, string kind, Guid? subgroup)
        {
            Alias = alias;
            Guid = guid;
            Kind = kind;
            SubgroupGuid = subgroup;
        }

        public override string ToString()
        {
            return Alias;
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

        // ---- settings (PR 3) ----

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadACValueIndex(IntPtr root, Guid[] scheme, Guid[] sub, Guid[] setting, out uint value);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadDCValueIndex(IntPtr root, Guid[] scheme, Guid[] sub, Guid[] setting, out uint value);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerWriteACValueIndex(IntPtr root, Guid[] scheme, Guid[] sub, Guid[] setting, uint value);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerWriteDCValueIndex(IntPtr root, Guid[] scheme, Guid[] sub, Guid[] setting, uint value);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadValueMin(IntPtr root, Guid[] sub, Guid[] setting, out uint value);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadValueMax(IntPtr root, Guid[] sub, Guid[] setting, out uint value);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadValueIncrement(IntPtr root, Guid[] sub, Guid[] setting, out uint value);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadValueUnitsSpecifier(IntPtr root, Guid[] sub, Guid[] setting, byte[] buffer, ref uint size);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadPossibleFriendlyName(IntPtr root, Guid[] sub, Guid[] setting, uint index, byte[] buffer, ref uint size);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadPossibleDescription(IntPtr root, Guid[] sub, Guid[] setting, uint index, byte[] buffer, ref uint size);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadSettingAttributes(Guid[] sub, Guid[] setting);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerWriteSettingAttributes(Guid[] sub, Guid[] setting, uint attributes);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerRemovePowerSetting(Guid[] sub, Guid[] setting);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerSettingAccessCheck(uint accessFlags, Guid[] powerGuid);

        [DllImport("powrprof.dll", ExactSpelling = true)]
        internal static extern uint PowerReadSecurityDescriptor(uint accessFlags, Guid[] powerGuid, out IntPtr sddl);

        [DllImport("powrprof.dll", ExactSpelling = true, CharSet = CharSet.Unicode)]
        internal static extern uint PowerWriteSecurityDescriptor(uint accessFlags, Guid[] powerGuid, string sddl);

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

        // ---------------------------------------------------------------
        // Settings
        // ---------------------------------------------------------------

        internal const uint ACCESS_AC_POWER_SETTING_INDEX = 0;
        internal const uint ACCESS_DC_POWER_SETTING_INDEX = 1;
        internal const uint ERROR_ACCESS_DISABLED_BY_POLICY = 1260;

        private delegate uint ReadUIntFn(IntPtr root, Guid[] sub, Guid[] setting, out uint value);

        private static uint? TryReadUInt(ReadUIntFn fn, Guid[] sub, Guid[] setting)
        {
            uint v;
            return fn(IntPtr.Zero, sub, setting, out v) == NativeMethods.ERROR_SUCCESS ? (uint?)v : null;
        }

        private delegate uint ReadIndexedStringFn(IntPtr root, Guid[] sub, Guid[] setting, uint index, byte[] buffer, ref uint size);

        // Returns null when the index does not exist.
        private static string TryReadIndexedString(ReadIndexedStringFn fn, Guid[] sub, Guid[] setting, uint index)
        {
            uint size = 0;
            uint rc = fn(IntPtr.Zero, sub, setting, index, null, ref size);
            if (rc != NativeMethods.ERROR_SUCCESS && rc != NativeMethods.ERROR_MORE_DATA) { return null; }
            if (size == 0) { return string.Empty; }
            byte[] buffer = new byte[size];
            if (fn(IntPtr.Zero, sub, setting, index, buffer, ref size) != NativeMethods.ERROR_SUCCESS) { return null; }
            return DecodeUnicode(buffer, size);
        }

        private static string DecodeUnicode(byte[] buffer, uint size)
        {
            string value = Encoding.Unicode.GetString(buffer, 0, ((int)size / 2) * 2);
            int nul = value.IndexOf('\0');
            return nul >= 0 ? value.Substring(0, nul) : value;
        }

        private static string TryReadUnits(Guid[] sub, Guid[] setting)
        {
            uint size = 0;
            uint rc = NativeMethods.PowerReadValueUnitsSpecifier(IntPtr.Zero, sub, setting, null, ref size);
            if ((rc != NativeMethods.ERROR_SUCCESS && rc != NativeMethods.ERROR_MORE_DATA) || size == 0) { return null; }
            byte[] buffer = new byte[size];
            if (NativeMethods.PowerReadValueUnitsSpecifier(IntPtr.Zero, sub, setting, buffer, ref size) != NativeMethods.ERROR_SUCCESS) { return null; }
            return DecodeUnicode(buffer, size);
        }

        public static uint ReadAcValue(Guid scheme, Guid subgroup, Guid setting)
        {
            uint v;
            Check("PowerReadACValueIndex", NativeMethods.PowerReadACValueIndex(IntPtr.Zero, new Guid[] { scheme }, new Guid[] { subgroup }, new Guid[] { setting }, out v));
            return v;
        }

        public static uint ReadDcValue(Guid scheme, Guid subgroup, Guid setting)
        {
            uint v;
            Check("PowerReadDCValueIndex", NativeMethods.PowerReadDCValueIndex(IntPtr.Zero, new Guid[] { scheme }, new Guid[] { subgroup }, new Guid[] { setting }, out v));
            return v;
        }

        public static void WriteAcValue(Guid scheme, Guid subgroup, Guid setting, uint value)
        {
            Check("PowerWriteACValueIndex", NativeMethods.PowerWriteACValueIndex(IntPtr.Zero, new Guid[] { scheme }, new Guid[] { subgroup }, new Guid[] { setting }, value));
        }

        public static void WriteDcValue(Guid scheme, Guid subgroup, Guid setting, uint value)
        {
            Check("PowerWriteDCValueIndex", NativeMethods.PowerWriteDCValueIndex(IntPtr.Zero, new Guid[] { scheme }, new Guid[] { subgroup }, new Guid[] { setting }, value));
        }

        public static uint ReadSettingAttributes(Guid subgroup, Guid setting)
        {
            return NativeMethods.PowerReadSettingAttributes(new Guid[] { subgroup }, new Guid[] { setting });
        }

        public static void WriteSettingAttributes(Guid subgroup, Guid setting, uint attributes)
        {
            Check("PowerWriteSettingAttributes", NativeMethods.PowerWriteSettingAttributes(new Guid[] { subgroup }, new Guid[] { setting }, attributes));
        }

        public static void RemoveSetting(Guid subgroup, Guid setting)
        {
            Check("PowerRemovePowerSetting", NativeMethods.PowerRemovePowerSetting(new Guid[] { subgroup }, new Guid[] { setting }));
        }

        // True when Group Policy overrides the value (ERROR_ACCESS_DISABLED_BY_POLICY).
        public static bool IsPolicyManaged(Guid setting, bool dc)
        {
            uint rc = NativeMethods.PowerSettingAccessCheck(dc ? ACCESS_DC_POWER_SETTING_INDEX : ACCESS_AC_POWER_SETTING_INDEX, new Guid[] { setting });
            return rc == ERROR_ACCESS_DISABLED_BY_POLICY;
        }

        public static PowerSetting GetSetting(Guid scheme, Guid subgroup, Guid setting, string subgroupName)
        {
            Guid[] sc = new Guid[] { scheme };
            Guid[] sg = new Guid[] { subgroup };
            Guid[] st = new Guid[] { setting };

            PowerSetting r = new PowerSetting();
            r.SchemeGuid = scheme;
            r.SubgroupGuid = subgroup;
            r.SubgroupName = subgroupName != null ? subgroupName : ReadFriendlyName(null, subgroup, null);
            r.SubgroupAlias = GetAliasName(subgroup);
            r.Guid = setting;
            r.Name = ReadFriendlyName(null, subgroup, setting);
            r.Alias = GetAliasName(setting);
            r.Description = ReadDescription(null, subgroup, setting);

            uint v;
            Check("PowerReadACValueIndex", NativeMethods.PowerReadACValueIndex(IntPtr.Zero, sc, sg, st, out v));
            r.AcValue = v;
            Check("PowerReadDCValueIndex", NativeMethods.PowerReadDCValueIndex(IntPtr.Zero, sc, sg, st, out v));
            r.DcValue = v;

            r.Minimum = TryReadUInt(NativeMethods.PowerReadValueMin, sg, st);
            r.IsRange = r.Minimum.HasValue;
            if (r.IsRange)
            {
                r.Maximum = TryReadUInt(NativeMethods.PowerReadValueMax, sg, st);
                r.Increment = TryReadUInt(NativeMethods.PowerReadValueIncrement, sg, st);
                r.Units = TryReadUnits(sg, st);
                r.PossibleValues = new PowerSettingValue[0];
            }
            else
            {
                List<PowerSettingValue> values = new List<PowerSettingValue>();
                for (uint i = 0; i < 1024; i++)
                {
                    string name = TryReadIndexedString(NativeMethods.PowerReadPossibleFriendlyName, sg, st, i);
                    if (name == null) { break; }
                    values.Add(new PowerSettingValue(i, name, TryReadIndexedString(NativeMethods.PowerReadPossibleDescription, sg, st, i)));
                }
                r.PossibleValues = values.ToArray();
                if (r.AcValue < values.Count) { r.AcValueName = values[(int)r.AcValue].Name; }
                if (r.DcValue < values.Count) { r.DcValueName = values[(int)r.DcValue].Name; }
            }

            r.Attributes = NativeMethods.PowerReadSettingAttributes(sg, st);
            r.AcPolicyManaged = IsPolicyManaged(setting, false);
            r.DcPolicyManaged = IsPolicyManaged(setting, true);
            return r;
        }

        // GUID_NO_SUBGROUP. PowerEnumerate never returns it as a subgroup, but
        // settings live under it (powercfg /q lists them first as "Settings
        // belonging to no subgroup"), so it is added explicitly.
        public static readonly Guid NoSubgroup = new Guid("fea3413e-7e05-4911-9a71-700331f1c294");

        // Subgroups of a scheme in powercfg order: SUB_NONE first, then what
        // PowerEnumerate returns.
        public static Guid[] EnumerateSubgroups(Guid scheme)
        {
            List<Guid> list = new List<Guid>();
            list.Add(NoSubgroup);
            foreach (Guid g in Enumerate(scheme, null, PowerDataAccessor.Subgroup))
            {
                if (g != NoSubgroup) { list.Add(g); }
            }
            return list.ToArray();
        }

        private static string SubgroupName(Guid subgroup)
        {
            try
            {
                return ReadFriendlyName(null, subgroup, null);
            }
            catch (System.ComponentModel.Win32Exception)
            {
                if (subgroup == NoSubgroup) { return "Settings belonging to no subgroup"; }
                throw;
            }
        }

        // subgroup/setting null = all. Hidden settings (ATTRIBUTE_HIDE) are
        // skipped unless includeHidden, matching powercfg /q vs /qh.
        public static PowerSetting[] GetSettings(Guid scheme, Guid? subgroup, Guid? setting, bool includeHidden)
        {
            List<PowerSetting> result = new List<PowerSetting>();
            Guid[] subgroups = subgroup.HasValue ? new Guid[] { subgroup.Value } : EnumerateSubgroups(scheme);
            foreach (Guid sg in subgroups)
            {
                string sgName = SubgroupName(sg);
                Guid[] settings = setting.HasValue ? new Guid[] { setting.Value } : Enumerate(scheme, sg, PowerDataAccessor.IndividualSetting);
                foreach (Guid st in settings)
                {
                    if (!includeHidden && !setting.HasValue && (NativeMethods.PowerReadSettingAttributes(new Guid[] { sg }, new Guid[] { st }) & 1) != 0)
                    {
                        continue;
                    }
                    result.Add(GetSetting(scheme, sg, st, sgName));
                }
            }
            return result.ToArray();
        }

        // Finds the subgroup that contains a setting: alias table first, then
        // by enumerating the scheme.
        public static Guid? FindSubgroup(Guid scheme, Guid setting)
        {
            EnsureAliases();
            Guid sg;
            if (s_settingSubgroup.TryGetValue(setting, out sg)) { return sg; }
            foreach (Guid g in EnumerateSubgroups(scheme))
            {
                foreach (Guid st in Enumerate(scheme, g, PowerDataAccessor.IndividualSetting))
                {
                    if (st == setting) { return g; }
                }
            }
            return null;
        }

        // ---------------------------------------------------------------
        // Security descriptors
        // ---------------------------------------------------------------

        public static string ReadSecurityDescriptor(uint accessor, Guid? guid)
        {
            IntPtr p;
            Check("PowerReadSecurityDescriptor", NativeMethods.PowerReadSecurityDescriptor(accessor, Wrap(guid), out p));
            try
            {
                return Marshal.PtrToStringUni(p);
            }
            finally
            {
                if (p != IntPtr.Zero) { NativeMethods.LocalFree(p); }
            }
        }

        public static void WriteSecurityDescriptor(uint accessor, Guid? guid, string sddl)
        {
            Check("PowerWriteSecurityDescriptor", NativeMethods.PowerWriteSecurityDescriptor(accessor, Wrap(guid), sddl));
        }

        // ---------------------------------------------------------------
        // Aliases: the table powercfg /aliasesh prints (captured on Windows 11
        // 10.0.26300). Two-space indent = top level, four = setting under the
        // SUB_ above it.
        // ---------------------------------------------------------------

        private static readonly object s_aliasLock = new object();
        private static PowerAlias[] s_aliases;
        private static Dictionary<string, PowerAlias> s_byName;
        private static Dictionary<Guid, string> s_byGuid;
        private static Dictionary<Guid, Guid> s_settingSubgroup;

        private static void EnsureAliases()
        {
            if (s_aliases != null) { return; }
            lock (s_aliasLock)
            {
                if (s_aliases != null) { return; }
                List<PowerAlias> list = new List<PowerAlias>();
                Dictionary<string, PowerAlias> byName = new Dictionary<string, PowerAlias>(StringComparer.OrdinalIgnoreCase);
                Dictionary<Guid, string> byGuid = new Dictionary<Guid, string>();
                Dictionary<Guid, Guid> settingSubgroup = new Dictionary<Guid, Guid>();
                Guid? currentSub = null;
                foreach (string raw in AliasTable.Split('\n'))
                {
                    string line = raw.TrimEnd('\r');
                    if (line.Trim().Length == 0) { continue; }
                    string trimmed = line.Trim();
                    int space = trimmed.IndexOf(' ');
                    Guid g = new Guid(trimmed.Substring(0, space));
                    string rest = trimmed.Substring(space);
                    string name = rest.Trim();
                    bool isSetting = rest.Length - rest.TrimStart(' ').Length >= 4;
                    string kind;
                    Guid? parent = null;
                    if (isSetting) { kind = "Setting"; parent = currentSub; }
                    else if (name.StartsWith("SUB_", StringComparison.Ordinal)) { kind = "Subgroup"; currentSub = g; }
                    else if (name.StartsWith("OVERLAY_SCHEME_", StringComparison.Ordinal)) { kind = "OverlayScheme"; currentSub = null; }
                    else if (name.StartsWith("PROFILE_", StringComparison.Ordinal)) { kind = "Profile"; currentSub = null; }
                    else { kind = "Scheme"; currentSub = null; }

                    PowerAlias a = new PowerAlias(name, g, kind, parent);
                    list.Add(a);
                    if (!byName.ContainsKey(name)) { byName.Add(name, a); }
                    if (!byGuid.ContainsKey(g)) { byGuid.Add(g, name); }
                    if (isSetting && parent.HasValue && !settingSubgroup.ContainsKey(g)) { settingSubgroup.Add(g, parent.Value); }
                }
                s_byName = byName;
                s_byGuid = byGuid;
                s_settingSubgroup = settingSubgroup;
                s_aliases = list.ToArray();
            }
        }

        public static PowerAlias[] GetAliases()
        {
            EnsureAliases();
            return (PowerAlias[])s_aliases.Clone();
        }

        public static string GetAliasName(Guid guid)
        {
            EnsureAliases();
            string name;
            return s_byGuid.TryGetValue(guid, out name) ? name : null;
        }

        public static readonly Guid SchemeCurrent = new Guid("31f9f286-5084-42fe-b720-2b0264993763");

        // GUID string or alias (SCHEME_CURRENT = the active scheme). Returns
        // null when it is neither.
        public static Guid? ResolveGuid(string value)
        {
            if (string.IsNullOrEmpty(value)) { return null; }
            Guid g;
            if (Guid.TryParse(value.Trim('{', '}', ' '), out g)) { return g; }
            EnsureAliases();
            PowerAlias a;
            if (s_byName.TryGetValue(value.Trim(), out a))
            {
                if (a.Guid == SchemeCurrent) { return GetActiveScheme(); }
                return a.Guid;
            }
            return null;
        }

        private const string AliasTable = @"
a1841308-3541-4fab-bc81-f71556f20b4a  SCHEME_MAX
8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c  SCHEME_MIN
381b4222-f694-41f0-9685-ff5bb260df2e  SCHEME_BALANCED
68a1e95e-13ea-41e1-8011-0c496ca490b0  SCHEME_ALL
31f9f286-5084-42fe-b720-2b0264993763  SCHEME_CURRENT
00000000-0000-0000-0000-000000000000  OVERLAY_SCHEME_NONE
3af9b8d9-7c97-431d-ad78-34a8bfea439f  OVERLAY_SCHEME_HIGH
ded574b5-45a0-4f42-8737-46345c09c238  OVERLAY_SCHEME_MAX
961cc777-2547-4f9d-8174-7d86181b8a7a  OVERLAY_SCHEME_MIN
0da965dc-8fcf-4c0b-8efe-8dd5e7bc959a  PROFILE_LOWLATENCY
4569e601-272e-4869-bcab-1c6c03d7966f  PROFILE_LOWPOWER
ee1e4f72-e368-46b1-b3c6-5048b11c2dbd  PROFILE_CONSTRAINED
8bc6262c-c026-411d-ae3b-7e2f70811a13  PROFILE_STANDBY
c04a802d-2205-4910-ae98-3b51e3bb72f2  PROFILE_BACKGROUND
a4a61b5f-f42c-4d23-b3ab-5c27df9f0f18  PROFILE_ENTRYLEVELPERF
0c3d5326-944b-4aab-8ad8-fe422a0e50e0  PROFILE_MULTIMEDIA
33cc3a0d-45ee-43ca-86c4-695bfc9a313b  PROFILE_UTILITY
336c7511-f109-4172-bb3a-3ea51f815ada  PROFILE_ECO
0aabb002-a307-447e-9b81-1d819df6c6d0  PROFILE_SUSTAINEDPERF
d4140c81-ebba-4e60-8561-6918290359cd  PROFILE_GAMEMODE
2e92e666-c3f6-42c3-89bd-94d40fabcde5  PROFILE_SCREENOFF
e73a048d-bf27-4f12-9731-8b2076e8891f  SUB_BATTERY
637ea02f-bbcb-4015-8e2c-a1c7b9c0b546    BATACTIONCRIT
d8742dcb-3e6a-4b3c-b3fe-374623cdcf06    BATACTIONLOW
5dbb7c9f-38e9-40d2-9749-4f8a0e9f640f    BATFLAGSCRIT
bcded951-187b-4d05-bccc-f7e51960c258    BATFLAGSLOW
9a66d8d7-4ff7-4ef9-b5a2-5a326ca2a469    BATLEVELCRIT
8183ba9a-e910-48da-8769-14ae6dc1170a    BATLEVELLOW
4f971e89-eebd-4455-a8de-9e59040e7347  SUB_BUTTONS
5ca83367-6e45-459f-a27b-476b1d01c936    LIDACTION
99ff10e7-23b1-4c07-a9d1-5c3206d741b4    LIDOPENWAKE
7648efa3-dd9c-4e3e-b566-50f929386280    PBUTTONACTION
96996bc0-ad50-47ec-923b-6f41874dd9eb    SBUTTONACTION
833a6b62-dfa4-46d1-82f8-e09e34d029d6    SHUTDOWN
a7066653-8d6c-40a8-910e-a1f54b84c7e5    UIBUTTON_ACTION
0012ee47-9041-4b5d-9b77-535fba8b1442  SUB_DISK
80e3c60e-bb94-4ad8-bbe0-0d3195efc663    DISKBURSTIGNORE
6738e2c4-e8a5-4a42-b16a-e040e769756e    DISKIDLE
51dea550-bb38-4bc4-991b-eacf37be5ec8    DISKMAXPOWER
fc7372b6-ab2d-43ee-8797-15e9841f2cca    DISKNVMENOPPME
d639518a-e56d-4345-8af2-b9f32fb26109    NVMEPRIMARYIDLETIMEOUT
de830923-a562-41af-a086-e3a2c6bad2da  SUB_ENERGYSAVER
e69653ca-cf7f-4f05-aa73-cb833fa90ad4    ESBATTTHRESHOLD
13d09884-f74e-474a-a852-b6bde8ad03a8    ESBRIGHTNESS
5c5bb349-ad29-4ee2-9d0b-2b25270f7a81    ESPOLICY
5fb4938d-1ee8-4b0f-9a3c-5036b0ab995c  SUB_GRAPHICS
dd848b2a-8a5d-4451-9ae2-39cd41658f6c    GPUPREFERENCEPOLICY
48672f38-7a9a-4bb2-8bf8-3d85be19de4e  SUB_INTSTEER
2bfc24f9-5ea2-4801-8213-3dbae01aa39d    MODE
73cde64d-d720-4bb2-a860-c755afe77ef2    PERPROCLOAD
d6ba4903-386f-4c2c-8adb-5c21b3328d25    UNPARKTIME
2e601130-5351-4d9d-8e04-252966bad054  SUB_IR
c36f0eb4-2988-4a70-8eee-0884fc2c2433    COALTIME
d502f7ee-1dc7-4efd-a55d-f04b6f5c0545    DEEPSLEEP
3166bc41-7e98-4e03-b34e-ec0f5f2b218e    EXECTIME
c42b79aa-aa3a-484b-a98f-2cf32aa90a28    PROCIR
fea3413e-7e05-4911-9a71-700331f1c294  SUB_NONE
f15576e8-98b7-4186-b944-eafa664402d9    CONNECTIVITYINSTANDBY
0e796bdb-100d-47d6-a2d5-f7d2daa51f51    CONSOLELOCK
4faab71a-92e5-4726-b531-224559672d19    DEVICEIDLE
68afb2d9-ee95-47a8-8f50-4115088073b1    DISCONNECTEDSTANDBYMODE
245d8541-3943-4422-b025-13a784f679b7    PERSONALITY
501a4d13-42af-4429-9fd1-a8218c268e20  SUB_PCIEXPRESS
ee12f906-d277-404b-b6da-e5fa1a576df5    ASPM
8619b916-e004-4dd8-9b66-dae86f806698  SUB_PRESENCE
cf8c6097-12b8-4279-bbdd-44601ee5209d    HUPRVIDEODIM
a79c8e0e-f271-482d-8f8a-5db9a18312de    HUPRVIDEODIMAWAY
0a7d6ab6-ac83-4ad1-8282-eca5b58308f3    HUPRVIDEOIDLE
ee16691e-6ab3-4619-bb48-1c77c9357e5a    HUPRVIDEOIDLEINATTENTIVE
5adbbfbc-074e-4da1-ba38-db8b36b2c8f3    NSENINPUTPRETIME
60c07fe1-0556-45cf-9903-d56e32210242    STANDBYBUDGETGRACEPERIOD
9fe527be-1b70-48da-930d-7bcf17b44990    STANDBYBUDGETPERCENT
aca8648e-c4b1-4baa-8cce-9390ad647f8c    STANDBYBUDGETREFRESHCOUNT
61f45dfe-1919-4180-bb46-8cc70e0b38f1    STANDBYBUDGETREFRESHINTERVAL
c763ee92-71e8-4127-84eb-f6ed043a3e3d    STANDBYRESERVEGRACEPERIOD
468fe7e5-1158-46ec-88bc-5b96c9e44fd0    STANDBYRESERVETIME
49cb11a5-56e2-4afb-9d38-3df47872e21b    STANDBYRESETPERCENT
82011705-fb95-4d46-8d35-4042b1d20def    USERPRESENCEPREDICTION
54533251-82be-4824-96c1-47b60b740d00  SUB_PROCESSOR
b669a5e9-7b1d-4132-baaa-49190abcfeb6    COMPLEXUNPARKPOLICY
2430ab6f-a520-44a2-9601-f7f23b5134b1    CPCONCURRENCY
71021b41-c749-4d21-be74-a00f335d582b    CPDECREASEPOL
dfd10d17-d5eb-45dd-877a-9a34ddd15c82    CPDECREASETIME
4bdaf4e9-d103-46d7-a5f0-6280121616ef    CPDISTRIBUTION
f735a673-2066-4f80-a0c5-ddee0cf1bf5d    CPHEADROOM
c7be0679-2817-4d69-9d02-519a537ed0c6    CPINCREASEPOL
2ddd5a84-5a71-437e-912a-db0b8c788732    CPINCREASETIME
ea062031-0e34-4ff1-9b6d-eb1059334028    CPMAXCORES
ea062031-0e34-4ff1-9b6d-eb1059334029    CPMAXCORES1
0cc5b647-c1df-4637-891a-dec35c318583    CPMINCORES
0cc5b647-c1df-4637-891a-dec35c318584    CPMINCORES1
943c8cb6-6f93-4227-ad87-e9a3feec08d1    CPOVERUTIL
447235c7-6a8d-4cc0-8e24-9eaf70b96e2b    CPPERF
447235c7-6a8d-4cc0-8e24-9eaf70b96e2c    CPPERF1
e0007330-f589-42ed-a401-5ddb10e785d3    DISTRIBUTEUTIL
fddc842b-8364-4edc-94cf-c17f60de1c80    HETEROCLASS0FLOORPERF
1facfc65-a930-4bc5-9f38-504ec097bbc0    HETEROCLASS1INITIALPERF
6ff13aeb-7897-4356-9999-dd9930af065f    HETEROCONTAINMENTDECREASETIME
6ece9e1f-b6dd-42bf-b1b7-5a512b10c092    HETEROCONTAINMENTEFFICIENCYIMPUTILTHRESHOLD
12fd031f-53d2-4bf4-ac6d-c699fc9538c7    HETEROCONTAINMENTHYBRIDIMPUTILTHRESHOLD
64fcee6b-5b1f-45a4-a76a-19b2c36ee290    HETEROCONTAINMENTINCREASETIME
60fbe21b-efd9-49f2-b066-8674d8e9f423    HETEROCONTAINMENTPOLICY
f8861c27-95e7-475c-865b-13c0cb3f9d6b    HETERODECREASETHRESHOLD
f8861c27-95e7-475c-865b-13c0cb3f9d6c    HETERODECREASETHRESHOLD1
7f2492b6-60b1-45e5-ae55-773f8cd5caec    HETERODECREASETIME
69439b22-221b-4830-bd34-f7bcece24583    HETEROEFFICIENCYCONTAINMENTTHRESHOLD
6788488b-1b90-4d11-8fa7-973e470dff47    HETEROHYBRIDCONTAINMENTTHRESHOLD
b000397d-9b0b-483d-98c9-692a6060cfbf    HETEROINCREASETHRESHOLD
b000397d-9b0b-483d-98c9-692a6060cfc0    HETEROINCREASETHRESHOLD1
4009efa7-e72d-4cba-9edf-91084ea8cbc3    HETEROINCREASETIME
7f2f5cfa-f10c-4823-b5e1-e93ae85f46b5    HETEROPOLICY
c4581c31-89ab-4597-8e2b-9c9cab440e6b    IDLECHECK
4b92d758-5a24-4851-a470-815d78aee119    IDLEDEMOTE
5d76a2ca-e8c0-402f-a133-2158492d58ad    IDLEDISABLE
7b224883-b3cc-4d79-819f-8374152cbe7c    IDLEPROMOTE
6c2993b0-8f48-481f-bcc6-00dd2742aa06    IDLESCALING
9943e905-9a30-4ec1-9b99-44dd3b76f7a2    IDLESTATEMAX
4b70f900-cdd9-4e66-aa26-ae8417f98173    LATENCYHINTEPP
4b70f900-cdd9-4e66-aa26-ae8417f98174    LATENCYHINTEPP1
4b70f900-cdd9-4e66-aa26-ae8417f98175    LATENCYHINTEPP2
619b7505-003b-4e82-b7a6-4dd29c300971    LATENCYHINTPERF
619b7505-003b-4e82-b7a6-4dd29c300972    LATENCYHINTPERF1
619b7505-003b-4e82-b7a6-4dd29c300973    LATENCYHINTPERF2
616cdaa5-695e-4545-97ad-97dc2d1bdd88    LATENCYHINTUNPARK
616cdaa5-695e-4545-97ad-97dc2d1bdd89    LATENCYHINTUNPARK1
43f278bc-0f8a-46d0-8b31-9a23e615d713    LONGTHREADARCHCLASSLOWERTHRESHOLD
bf903d33-9d24-49d3-a468-e65e0325046a    LONGTHREADARCHCLASSUPPERTHRESHOLD
b0deaf6b-59c0-4523-8a45-ca7f40244114    MODULEUNPARKPOLICY
8baa4a8a-14c6-4451-8e8b-14bdbd197537    PERFAUTONOMOUS
cfeda3d0-7697-4566-a922-a9086cd49dfa    PERFAUTONOMOUSWINDOW
be337238-0d82-4146-a960-4f3749d470c7    PERFBOOSTMODE
45bcc044-d885-43e2-8605-ee0ec6e96b59    PERFBOOSTPOL
4d2b0152-7d5c-498b-88e2-34345392a2c5    PERFCHECK
40fbefc7-2e9d-4d25-a185-0cfd8574bac6    PERFDECPOL
40fbefc7-2e9d-4d25-a185-0cfd8574bac7    PERFDECPOL1
12a0ab44-fe28-4fa9-b3bd-4b64f44960a6    PERFDECTHRESHOLD
12a0ab44-fe28-4fa9-b3bd-4b64f44960a7    PERFDECTHRESHOLD1
d8edeb9b-95cf-4f95-a73c-b061973693c8    PERFDECTIME
d8edeb9b-95cf-4f95-a73c-b061973693c9    PERFDECTIME1
4e4450b3-6179-4e91-b8f1-5bb9938f81a1    PERFDUTYCYCLING
36687f9e-e3a5-4dbf-b1dc-15eb381c6863    PERFEPP
36687f9e-e3a5-4dbf-b1dc-15eb381c6864    PERFEPP1
36687f9e-e3a5-4dbf-b1dc-15eb381c6865    PERFEPP2
7d24baa7-0b84-480f-840c-1b0743c00f5f    PERFHISTORY
7d24baa7-0b84-480f-840c-1b0743c00f60    PERFHISTORY1
465e1f50-b610-473a-ab58-00d1077dc418    PERFINCPOL
465e1f50-b610-473a-ab58-00d1077dc419    PERFINCPOL1
06cadf0e-64ed-448a-8927-ce7bf90eb35d    PERFINCTHRESHOLD
06cadf0e-64ed-448a-8927-ce7bf90eb35e    PERFINCTHRESHOLD1
984cf492-3bed-4488-a8f9-4286c97bf5aa    PERFINCTIME
984cf492-3bed-4488-a8f9-4286c97bf5ab    PERFINCTIME1
75b0ae3f-bce0-45a7-8c89-c9611c25e100    PROCFREQMAX
75b0ae3f-bce0-45a7-8c89-c9611c25e101    PROCFREQMAX1
75b0ae3f-bce0-45a7-8c89-c9611c25e102    PROCFREQMAX2
bc5038f7-23e0-4960-96da-33abaf5935ec    PROCTHROTTLEMAX
bc5038f7-23e0-4960-96da-33abaf5935ed    PROCTHROTTLEMAX1
bc5038f7-23e0-4960-96da-33abaf5935ee    PROCTHROTTLEMAX2
893dee8e-2bef-41e0-89c6-b55d0929964c    PROCTHROTTLEMIN
893dee8e-2bef-41e0-89c6-b55d0929964d    PROCTHROTTLEMIN1
893dee8e-2bef-41e0-89c6-b55d0929964e    PROCTHROTTLEMIN2
603fe9ce-8d01-4b48-a968-1d706c28fd5c    RESOURCEPRIORITY
603fe9ce-8d01-4b48-a968-1d706c28fd5d    RESOURCEPRIORITY1
603fe9ce-8d01-4b48-a968-1d706c28fd5e    RESOURCEPRIORITY2
1a98ad09-af22-42ca-8e61-f0a5802c270a    RESTRICTIONCOUNT
93b8b6dc-0698-4d1c-9ee4-0644e900c85d    SCHEDPOLICY
bae08b81-2d5e-4688-ad6a-13243356654b    SHORTSCHEDPOLICY
53824d46-87bd-4739-aa1b-aa793fac36d6    SHORTTHREADARCHCLASSLOWERTHRESHOLD
828423eb-8662-4344-90f7-52bf15870f5a    SHORTTHREADARCHCLASSUPPERTHRESHOLD
d92998c2-6a48-49ca-85d4-8cceec294570    SHORTTHREADRUNTIMETHRESHOLD
b28a6829-c5f7-444e-8f61-10e24e85c532    SMTUNPARKPOLICY
97cfac41-2217-47eb-992d-618b1977c907    SOFTPARKLATENCY
94d3a615-a899-4ac5-ae2b-e4d8f634367f    SYSCOOLPOL
3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb    THROTTLING
5ba7419a-295c-4b02-841b-66799388d6da    WPSMINEFFICIENCYTHRESHOLD
238c9fa8-0aad-41ed-83f4-97be242c8f20  SUB_SLEEP
abfc2519-3608-4c2a-94ea-171b0ed546ab    ALLOWSTANDBY
25dfa149-5dd1-4736-b5ab-e8a37b5b8187    AWAYMODE
9d7815a6-7ee4-497e-8888-515a05f02364    HIBERNATEIDLE
94ac6d29-73ce-41a6-809f-6363ba21b47e    HYBRIDSLEEP
1a34bdc3-7e6b-442e-a9d0-64b6ef378e84    LEGACYRTCMITIGATION
d4c1d4c8-d5cc-43d3-b83e-fc51215cb04d    REMOTEFILESLEEP
bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d    RTCWAKE
29f6c1db-86da-48c5-9fdb-f2b67b1f44da    STANDBYIDLE
a4b195f5-8225-47d8-8012-9d41369786e2    SYSTEMREQUIRED
7bc4a2f9-d8fc-4469-b07b-33eb785aaca0    UNATTENDSLEEP
7516b95f-f776-4464-8c53-06167f40cc99  SUB_VIDEO
fbd9aa66-9553-4097-ba44-ed6e9d65eab8    ADAPTBRIGHT
684c3e69-a4f7-4014-8754-d45179a56167    ADVANCEDCOLORQUALITYBIAS
a9ceb8da-cd46-44fb-a98b-02af69de4623    ALLOWDISPLAY
90959d22-d6a1-49b9-af93-bce885ad335b    VIDEOADAPT
8ec4b3a5-6868-48c2-be75-4f3044be88a7    VIDEOCONLOCK
17aaa29b-8b43-4b94-aafe-35f64daaf1ee    VIDEODIM
3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e    VIDEOIDLE
aded5e82-b909-4619-9949-f5d71dac0bcb    VIDEONORMALLEVEL
";
    }
}
