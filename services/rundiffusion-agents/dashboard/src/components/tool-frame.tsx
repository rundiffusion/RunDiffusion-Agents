import { ArrowUpRight, TriangleAlert, Wrench } from "lucide-react";

import { ToolHelpDialog } from "./tool-help-dialog";
import { Badge } from "./ui/badge";
import { Button } from "./ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "./ui/card";

export type ToolHelpCommand = {
  label: string;
  command: string;
  description?: string;
};

export type ToolHelpSection = {
  title: string;
  description?: string;
  tips?: string[];
  commands?: ToolHelpCommand[];
  directories?: string[];
};

export type ToolHelpDefinition = {
  title: string;
  description: string;
  sections: ToolHelpSection[];
};

export type ToolDefinition = {
  id: string;
  label: string;
  tabTitle?: string;
  description: string;
  path: string;
  enabled: boolean;
  help?: ToolHelpDefinition | null;
};

type ToolFrameProps = {
  brandName: string;
  tool: ToolDefinition;
  openclawAccessMode: string;
  busyActionId?: string | null;
  onRestartOpenClaw?: () => Promise<void> | void;
};

export function ToolFrame({ brandName, tool, openclawAccessMode, busyActionId, onRestartOpenClaw }: ToolFrameProps) {
  const isOpenClaw = tool.id === "openclaw";
  const isRestartingOpenClaw = busyActionId === "restart-openclaw";

  return (
    <div className="flex h-full min-h-0 flex-col gap-5">
      <Card>
        <CardHeader className="gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div className="space-y-3">
            <div className="flex flex-wrap items-center gap-3">
              <Badge variant={tool.enabled ? "success" : "muted"}>{tool.enabled ? "Available" : "Disabled"}</Badge>
              {isOpenClaw ? (
                <Badge variant="warning">{openclawAccessMode === "native" ? "Native auth" : "Proxy auth"}</Badge>
              ) : null}
            </div>
            <div>
              <CardTitle className="text-2xl">{tool.label}</CardTitle>
              <CardDescription className="mt-2 max-w-3xl">{tool.description}</CardDescription>
              {isOpenClaw ? (
                <CardDescription className="mt-3 max-w-4xl text-zinc-300">
                  OpenClaw stays on its existing native auth flow here. If the embedded view asks you to
                  connect or pair a device, that is expected. The other operator tools share the
                  dashboard&apos;s Basic Auth more directly than OpenClaw does.
                </CardDescription>
              ) : null}
            </div>
          </div>

          <div className="flex shrink-0 flex-wrap gap-3">
            {tool.help ? <ToolHelpDialog brandName={brandName} tool={tool} /> : null}
            {isOpenClaw ? (
              <Button
                variant="destructive"
                onClick={() => void onRestartOpenClaw?.()}
                disabled={isRestartingOpenClaw}
              >
                <Wrench className="h-4 w-4" />
                Restart Agent
              </Button>
            ) : null}
            <Button
              className="shrink-0"
              variant="outline"
              onClick={() => {
                window.open(tool.path, "_blank", "noopener,noreferrer");
              }}
            >
              <ArrowUpRight className="h-4 w-4" />
              Open in new tab
            </Button>
          </div>
        </CardHeader>
      </Card>

      {!tool.enabled ? (
        <Card className="flex-1">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <TriangleAlert className="h-5 w-5 text-amber-300" />
              Route disabled
            </CardTitle>
            <CardDescription>
              This tool is currently disabled in the gateway runtime. Re-enable the related `*_ENABLED`
              setting if you want it to appear live in the dashboard.
            </CardDescription>
          </CardHeader>
        </Card>
      ) : (
        <Card className="flex min-h-0 flex-1 flex-col overflow-hidden">
          <div className="border-b border-zinc-800/80 px-6 py-4 text-xs font-medium uppercase tracking-[0.22em] text-zinc-500">
            Embedded view
          </div>
          <div className="min-h-0 flex-1 bg-white">
            <iframe
              key={tool.id}
              title={tool.label}
              src={tool.path}
              className="h-full w-full border-0"
              referrerPolicy="same-origin"
            />
          </div>
        </Card>
      )}
    </div>
  );
}
