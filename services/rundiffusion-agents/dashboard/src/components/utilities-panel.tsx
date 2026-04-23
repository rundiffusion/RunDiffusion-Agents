import type { ReactNode } from "react";
import { LoaderCircle, RefreshCcw, TerminalSquare, Wrench } from "lucide-react";

import { cn } from "../lib/utils";
import { Badge } from "./ui/badge";
import { Button } from "./ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "./ui/card";

export type UtilityDefinition = {
  id: string;
  label: string;
  description: string;
};

export type DeviceApproval = {
  requestId: string;
  client: string;
  platform: string;
  remoteIp: string;
  createdAt: string;
  role: string;
  scopes: string[];
};

export type ActionResult = {
  kind: "success" | "error";
  title: string;
  detail?: string;
} | null;

type UtilitiesPanelProps = {
  utilities: UtilityDefinition[];
  selectedUtilityId: string;
  deviceApprovals: DeviceApproval[];
  isLoadingApprovals: boolean;
  approvalsError: string | null;
  approvingRequestId: string | null;
  busyActionId: string | null;
  actionResult: ActionResult;
  onRefreshApprovals: () => Promise<void> | void;
  onApproveRequest: (requestId: string) => Promise<void> | void;
  onRestartOpenClaw: () => Promise<void> | void;
};

function UtilityCard({
  utility,
  selectedUtilityId,
  children,
}: {
  utility: UtilityDefinition;
  selectedUtilityId: string;
  children: ReactNode;
}) {
  const isSelected = utility.id === selectedUtilityId;

  return (
    <Card
      className={cn(
        "transition-colors",
        isSelected && "border-cyan-400/40 bg-cyan-400/5 shadow-[0_20px_60px_-40px_rgba(34,211,238,0.55)]",
      )}
    >
      <CardHeader className="gap-2 p-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <CardTitle>{utility.label}</CardTitle>
            <CardDescription className="mt-1.5">{utility.description}</CardDescription>
          </div>
          {isSelected ? <Badge>Selected</Badge> : <Badge variant="muted">Utility</Badge>}
        </div>
      </CardHeader>
      <CardContent className="px-4 pb-4">{children}</CardContent>
    </Card>
  );
}

export function UtilitiesPanel({
  utilities,
  selectedUtilityId,
  deviceApprovals,
  isLoadingApprovals,
  approvalsError,
  approvingRequestId,
  busyActionId,
  actionResult,
  onRefreshApprovals,
  onApproveRequest,
  onRestartOpenClaw,
}: UtilitiesPanelProps) {
  const deviceApprovalUtility = utilities.find((utility) => utility.id === "device-approvals");
  const restartUtility = utilities.find((utility) => utility.id === "restart-openclaw");

  return (
    <div className="flex h-full min-h-0 flex-col gap-4 overflow-y-auto pr-1">
      <Card>
        <CardHeader className="gap-2 p-4">
          <div className="flex flex-wrap items-center gap-3">
            <Badge variant="warning">Operator actions</Badge>
            <Badge variant="muted">Safe wrappers only</Badge>
          </div>
          <CardTitle className="text-xl">Utilities</CardTitle>
          <CardDescription className="max-w-3xl">
            Recovery helpers live here so the dashboard can stay the front door for both app access and
            quick operator tasks.
          </CardDescription>
        </CardHeader>
      </Card>

      {actionResult ? (
        <Card className={cn(actionResult.kind === "success" ? "border-emerald-400/30" : "border-rose-400/30")}>
          <CardContent className="px-4 py-4">
            <div
              className={cn(
                "text-sm font-medium",
                actionResult.kind === "success" ? "text-emerald-200" : "text-rose-200",
              )}
            >
              {actionResult.title}
            </div>
            {actionResult.detail ? <p className="mt-2 text-sm leading-6 text-zinc-300">{actionResult.detail}</p> : null}
          </CardContent>
        </Card>
      ) : null}

      <div className="grid gap-4 xl:grid-cols-[1.25fr_1fr]">
        {deviceApprovalUtility ? (
          <UtilityCard utility={deviceApprovalUtility} selectedUtilityId={selectedUtilityId}>
            <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
              <div className="text-sm text-zinc-400">
                Pending requests: <span className="font-medium text-zinc-100">{deviceApprovals.length}</span>
              </div>
              <Button variant="outline" size="sm" onClick={() => void onRefreshApprovals()} disabled={isLoadingApprovals}>
                {isLoadingApprovals ? <LoaderCircle className="h-4 w-4 animate-spin" /> : <RefreshCcw className="h-4 w-4" />}
                Refresh
              </Button>
            </div>

            {approvalsError ? (
              <div className="rounded-2xl border border-rose-400/30 bg-rose-400/10 p-4 text-sm text-rose-100">
                {approvalsError}
              </div>
            ) : null}

            {deviceApprovals.length === 0 && !isLoadingApprovals && !approvalsError ? (
              <div className="rounded-2xl border border-dashed border-zinc-800 p-4 text-sm leading-6 text-zinc-400">
                No pending device pairing requests right now.
              </div>
            ) : null}

            <div className="space-y-3">
              {deviceApprovals.map((request) => (
                <div
                  key={request.requestId}
                  className="rounded-2xl border border-zinc-800/80 bg-zinc-900/55 p-3.5"
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <div className="text-sm font-medium text-zinc-50">{request.client}</div>
                      <div className="mt-1 text-xs uppercase tracking-[0.18em] text-zinc-500">{request.platform}</div>
                    </div>
                    <Button
                      size="sm"
                      onClick={() => void onApproveRequest(request.requestId)}
                      disabled={approvingRequestId === request.requestId}
                    >
                      {approvingRequestId === request.requestId ? (
                        <LoaderCircle className="h-4 w-4 animate-spin" />
                      ) : (
                        <TerminalSquare className="h-4 w-4" />
                      )}
                      Approve
                    </Button>
                  </div>

                  <dl className="mt-3 grid gap-2 text-sm text-zinc-400 sm:grid-cols-2">
                    <div>
                      <dt className="text-zinc-500">Remote IP</dt>
                      <dd>{request.remoteIp}</dd>
                    </div>
                    <div>
                      <dt className="text-zinc-500">Requested at</dt>
                      <dd>{request.createdAt}</dd>
                    </div>
                    <div>
                      <dt className="text-zinc-500">Role</dt>
                      <dd>{request.role}</dd>
                    </div>
                    <div>
                      <dt className="text-zinc-500">Scopes</dt>
                      <dd>{request.scopes.length > 0 ? request.scopes.join(", ") : "none"}</dd>
                    </div>
                  </dl>
                </div>
              ))}
            </div>
          </UtilityCard>
        ) : null}

        <div className="space-y-4">
          {restartUtility ? (
            <UtilityCard utility={restartUtility} selectedUtilityId={selectedUtilityId}>
              <div className="space-y-3 text-sm leading-6 text-zinc-400">
                <p>
                  Trigger the managed gateway restart helper and wait for the main OpenClaw health check to
                  recover.
                </p>
                <Button
                  variant="destructive"
                  onClick={() => void onRestartOpenClaw()}
                  disabled={busyActionId === restartUtility.id}
                >
                  {busyActionId === restartUtility.id ? (
                    <LoaderCircle className="h-4 w-4 animate-spin" />
                  ) : (
                    <Wrench className="h-4 w-4" />
                  )}
                  Restart Agent
                </Button>
              </div>
            </UtilityCard>
          ) : null}

          <Card>
            <CardHeader className="gap-2 p-4">
              <CardTitle>More helpers</CardTitle>
              <CardDescription>
                This section is intentionally ready for future recovery tools and operator workflows.
              </CardDescription>
            </CardHeader>
            <CardContent className="px-4 pb-4 text-sm leading-6 text-zinc-400">
              Keep new utilities behind the same narrow dashboard API pattern so the UI stays simple and the
              server only exposes explicit, reviewable actions.
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
