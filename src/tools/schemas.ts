import { z } from "zod";
export const threadContextSchema = z
    .number()
    .describe("The thread identity to execute the code in (default: 8, normal game scripts run on 2)")
    .optional()
    .default(8);
export const maxOutputCharsSchema = z
    .number()
    .describe("Maximum characters to return to the model (default: 6000, max: 32000). Raise only when a single result genuinely needs more; large outputs degrade model performance.")
    .optional()
    .default(6000);
