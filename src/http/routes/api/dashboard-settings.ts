import type { IncomingMessage, ServerResponse } from "http";
import { dashboardSettingsExist, loadDashboardSettings, saveDashboardSettings, type DashboardSettingsInput, } from "../../../dashboard/settings.js";
import { readJsonBody } from "../../body.js";
function respondJson(res: ServerResponse, status: number, body: unknown): void {
    res.writeHead(status, {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
    });
    res.end(JSON.stringify(body));
}
export async function GET(_req: IncomingMessage, res: ServerResponse): Promise<void> {
    const [settings, persisted] = await Promise.all([
        loadDashboardSettings(),
        dashboardSettingsExist(),
    ]);
    respondJson(res, 200, { ...settings, persisted });
}
export async function PUT(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const body = await readJsonBody<DashboardSettingsInput>(req);
        const settings = await saveDashboardSettings(body);
        respondJson(res, 200, { ...settings, persisted: true });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "Invalid dashboard settings.";
        respondJson(res, 400, { error: message });
    }
}
