import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
const fileTransactions = new Map<string, Promise<unknown>>();
export async function withFileTransaction<T>(filePath: string, operation: () => Promise<T>): Promise<T> {
    const previous = fileTransactions.get(filePath) ?? Promise.resolve();
    const current = previous.catch(() => undefined).then(operation);
    fileTransactions.set(filePath, current);
    try {
        return await current;
    }
    finally {
        if (fileTransactions.get(filePath) === current)
            fileTransactions.delete(filePath);
    }
}
export async function writeJsonAtomic(filePath: string, value: unknown, mode = 0o600): Promise<void> {
    await fs.mkdir(path.dirname(filePath), { recursive: true });
    const temporaryPath = `${filePath}.${process.pid}.${crypto.randomUUID()}.tmp`;
    let committed = false;
    try {
        const handle = await fs.open(temporaryPath, "wx", mode);
        try {
            await handle.writeFile(`${JSON.stringify(value, null, 2)}\n`, "utf8");
            await handle.sync();
        }
        finally {
            await handle.close();
        }
        await fs.rename(temporaryPath, filePath);
        committed = true;
        await fs.chmod(filePath, mode).catch(() => undefined);
    }
    finally {
        if (!committed)
            await fs.unlink(temporaryPath).catch(() => undefined);
    }
}
