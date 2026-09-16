import crypto from "node:crypto";
export type ProgressStatus = "running" | "done" | "error";
export interface ProgressJob {
    id: string;
    type: string;
    status: ProgressStatus;
    message: string;
    completed: number;
    total: number;
    result?: string;
    error?: string;
    startedAt: number;
    updatedAt: number;
}
const jobs: Map<string, ProgressJob> = new Map();
const JOB_TTL_MS = 15 * 60 * 1000;
function pruneJobs(): void {
    const cutoff = Date.now() - JOB_TTL_MS;
    for (const [id, job] of jobs) {
        if (job.updatedAt < cutoff)
            jobs.delete(id);
    }
}
export function createProgressJob(type: string, message: string): ProgressJob {
    pruneJobs();
    const now = Date.now();
    const job: ProgressJob = {
        id: crypto.randomUUID(),
        type,
        status: "running",
        message,
        completed: 0,
        total: 0,
        startedAt: now,
        updatedAt: now,
    };
    jobs.set(job.id, job);
    return job;
}
export function updateProgressJob(id: string, patch: Partial<Pick<ProgressJob, "message" | "completed" | "total">>): void {
    const job = jobs.get(id);
    if (!job || job.status !== "running")
        return;
    Object.assign(job, patch, { updatedAt: Date.now() });
}
export function completeProgressJob(id: string, result: string): void {
    const job = jobs.get(id);
    if (!job)
        return;
    job.status = "done";
    job.result = result;
    job.message = "Completed";
    job.completed = job.total || job.completed;
    job.updatedAt = Date.now();
}
export function failProgressJob(id: string, error: string): void {
    const job = jobs.get(id);
    if (!job)
        return;
    job.status = "error";
    job.error = error;
    job.message = error;
    job.updatedAt = Date.now();
}
export function getProgressJob(id: string): ProgressJob | undefined {
    pruneJobs();
    return jobs.get(id);
}
