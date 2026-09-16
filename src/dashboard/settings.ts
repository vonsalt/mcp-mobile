import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { withFileTransaction, writeJsonAtomic } from "../shared/atomic-json.js";
export const DASHBOARD_THEME_IDS = [
    "default",
    "claude",
    "chatgpt",
    "github-dark",
    "github-light",
    "custom",
] as const;
export const DASHBOARD_SANS_FONT_IDS = [
    "geist",
    "ibm-plex",
    "source-sans",
    "system",
    "custom",
] as const;
export const DASHBOARD_MONO_FONT_IDS = [
    "geist-mono",
    "ibm-plex-mono",
    "jetbrains-mono",
    "system-mono",
    "custom",
] as const;
export type DashboardThemeId = (typeof DASHBOARD_THEME_IDS)[number];
export type DashboardSansFontId = (typeof DASHBOARD_SANS_FONT_IDS)[number];
export type DashboardMonoFontId = (typeof DASHBOARD_MONO_FONT_IDS)[number];
export interface DashboardThemeColors {
    background: string;
    surface: string;
    raised: string;
    border: string;
    accent: string;
    text: string;
    muted: string;
}
export interface DashboardThemeFonts {
    sans: DashboardSansFontId;
    mono: DashboardMonoFontId;
    customSans: string;
    customMono: string;
}
export interface DashboardBackgroundMedia {
    type: "none" | "image" | "video";
    url: string;
    fit: "cover" | "contain";
    opacity: number;
}
export interface DashboardSettings {
    version: 1;
    theme: DashboardThemeId;
    colors: DashboardThemeColors;
    fonts: DashboardThemeFonts;
    backgroundMedia: DashboardBackgroundMedia;
}
export type DashboardSettingsInput = Partial<{
    version: unknown;
    theme: unknown;
    colors: unknown;
    fonts: unknown;
    backgroundMedia: unknown;
}>;
export const DASHBOARD_CONFIG_DIR = path.join(os.homedir(), ".roblox-mcp");
export const DASHBOARD_SETTINGS_PATH = path.join(DASHBOARD_CONFIG_DIR, "dashboard-settings.json");
export const DEFAULT_DASHBOARD_SETTINGS: DashboardSettings = {
    version: 1,
    theme: "default",
    colors: {
        background: "#0a0a0a",
        surface: "#111111",
        raised: "#171717",
        border: "#262626",
        accent: "#3b82f6",
        text: "#ededed",
        muted: "#a1a1a1",
    },
    fonts: {
        sans: "geist",
        mono: "geist-mono",
        customSans: "",
        customMono: "",
    },
    backgroundMedia: {
        type: "none",
        url: "",
        fit: "cover",
        opacity: 0.35,
    },
};
function isObject(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}
function normalizeEnum<T extends string>(value: unknown, allowed: readonly T[], fallback: T): T {
    return typeof value === "string" && allowed.includes(value as T)
        ? (value as T)
        : fallback;
}
function normalizeHex(value: unknown, fallback: string): string {
    if (typeof value !== "string")
        return fallback;
    const normalized = value.trim().toLowerCase();
    return /^#[0-9a-f]{6}$/.test(normalized) ? normalized : fallback;
}
function normalizeFontName(value: unknown, fallback: string): string {
    if (typeof value !== "string")
        return fallback;
    const normalized = value.trim();
    return /^[a-z0-9 _-]{0,60}$/i.test(normalized) ? normalized : fallback;
}
function normalizeMediaUrl(value: unknown, fallback: string): string {
    if (typeof value !== "string")
        return fallback;
    const normalized = value.trim();
    if (!normalized)
        return "";
    if (normalized.length > 2048)
        return fallback;
    if (normalized.startsWith("/") && !normalized.startsWith("//"))
        return normalized;
    try {
        const url = new URL(normalized);
        return url.protocol === "http:" || url.protocol === "https:" ? normalized : fallback;
    }
    catch {
        return fallback;
    }
}
function normalizeOpacity(value: unknown, fallback: number): number {
    const parsed = typeof value === "number" ? value : Number(value);
    return Number.isFinite(parsed) ? Math.min(1, Math.max(0.05, parsed)) : fallback;
}
export function normalizeDashboardSettings(value: unknown, fallback: DashboardSettings = DEFAULT_DASHBOARD_SETTINGS): DashboardSettings {
    const input = isObject(value) ? value : {};
    const colors = isObject(input.colors) ? input.colors : {};
    const fonts = isObject(input.fonts) ? input.fonts : {};
    const backgroundMedia = isObject(input.backgroundMedia) ? input.backgroundMedia : {};
    return {
        version: 1,
        theme: normalizeEnum(input.theme, DASHBOARD_THEME_IDS, fallback.theme),
        colors: {
            background: normalizeHex(colors.background, fallback.colors.background),
            surface: normalizeHex(colors.surface, fallback.colors.surface),
            raised: normalizeHex(colors.raised, fallback.colors.raised),
            border: normalizeHex(colors.border, fallback.colors.border),
            accent: normalizeHex(colors.accent, fallback.colors.accent),
            text: normalizeHex(colors.text, fallback.colors.text),
            muted: normalizeHex(colors.muted, fallback.colors.muted),
        },
        fonts: {
            sans: normalizeEnum(fonts.sans, DASHBOARD_SANS_FONT_IDS, fallback.fonts.sans),
            mono: normalizeEnum(fonts.mono, DASHBOARD_MONO_FONT_IDS, fallback.fonts.mono),
            customSans: normalizeFontName(fonts.customSans, fallback.fonts.customSans),
            customMono: normalizeFontName(fonts.customMono, fallback.fonts.customMono),
        },
        backgroundMedia: {
            type: normalizeEnum(backgroundMedia.type, ["none", "image", "video"] as const, fallback.backgroundMedia.type),
            url: normalizeMediaUrl(backgroundMedia.url, fallback.backgroundMedia.url),
            fit: normalizeEnum(backgroundMedia.fit, ["cover", "contain"] as const, fallback.backgroundMedia.fit),
            opacity: normalizeOpacity(backgroundMedia.opacity, fallback.backgroundMedia.opacity),
        },
    };
}
export async function dashboardSettingsExist(): Promise<boolean> {
    try {
        await fs.access(DASHBOARD_SETTINGS_PATH);
        return true;
    }
    catch (error) {
        if ((error as NodeJS.ErrnoException).code === "ENOENT")
            return false;
        throw error;
    }
}
export async function loadDashboardSettings(): Promise<DashboardSettings> {
    try {
        const raw = await fs.readFile(DASHBOARD_SETTINGS_PATH, "utf8");
        return normalizeDashboardSettings(JSON.parse(raw));
    }
    catch (error) {
        if ((error as NodeJS.ErrnoException).code === "ENOENT") {
            return normalizeDashboardSettings(DEFAULT_DASHBOARD_SETTINGS);
        }
        throw error;
    }
}
export async function saveDashboardSettings(input: DashboardSettingsInput): Promise<DashboardSettings> {
    if (!isObject(input))
        throw new Error("Dashboard settings must be a JSON object.");
    return withFileTransaction(DASHBOARD_SETTINGS_PATH, async () => {
        const existing = await loadDashboardSettings();
        const next = normalizeDashboardSettings(input, existing);
        await writeJsonAtomic(DASHBOARD_SETTINGS_PATH, next);
        return next;
    });
}
