import { useCallback, useEffect, useMemo, useState } from "react";
import { LoaderCircle } from "lucide-react";

import { AppShell } from "./components/app-shell";
import { ToolFrame, type ToolDefinition } from "./components/tool-frame";
import {
  UtilitiesPanel,
  type ActionResult,
  type DeviceApproval,
  type UtilityDefinition,
} from "./components/utilities-panel";
import { Card, CardDescription, CardHeader, CardTitle } from "./components/ui/card";

type DashboardConfig = {
  brandName: string;
  titleSuffix: string;
  tenantLabel: string;
  title: string;
  subtitle: string;
  openclawAccessMode: string;
  preferences: DashboardPreferences;
  tools: ToolDefinition[];
  utilities: UtilityDefinition[];
};

type DashboardPreferences = {
  toolOrder: string[];
  defaultToolOrder: string[];
};

type PreferencesResponse = {
  preferences: DashboardPreferences;
  config: DashboardConfig;
};

const CONFIG_ENDPOINT = "/dashboard-api/config";
const PREFERENCES_ENDPOINT = "/dashboard-api/preferences";
const DEVICE_APPROVALS_ENDPOINT = "/dashboard-api/utilities/device-approvals";
const RESTART_ENDPOINT = "/dashboard-api/utilities/restart-gateway";

function composeDocumentTitle(viewLabel: string, tenantLabel: string, titleSuffix: string) {
  return `${viewLabel} | ${tenantLabel} | ${titleSuffix}`;
}

function readSelectedView() {
  const hash = window.location.hash;
  if (!hash.startsWith("#view=")) return "";
  return decodeURIComponent(hash.slice("#view=".length));
}

function writeSelectedView(viewId: string) {
  const nextHash = `#view=${encodeURIComponent(viewId)}`;
  if (window.location.hash === nextHash) return;
  window.history.replaceState(null, "", `${window.location.pathname}${window.location.search}${nextHash}`);
}

function resolveViewId(config: DashboardConfig, preferredViewId = "") {
  const candidate = preferredViewId.trim();
  const availableIds = new Set([...config.tools.map((tool) => tool.id), ...config.utilities.map((utility) => utility.id)]);
  if (candidate && availableIds.has(candidate)) {
    return candidate;
  }

  return config.tools[0]?.id || config.utilities[0]?.id || "";
}

async function fetchJson<T>(input: RequestInfo, init?: RequestInit): Promise<T> {
  const response = await fetch(input, {
    ...init,
    headers: {
      Accept: "application/json",
      ...(init?.headers || {}),
    },
  });

  const text = await response.text();
  let data: unknown = null;

  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = null;
    }
  }

  if (!response.ok) {
    let message = `Request failed with ${response.status}`;

    if (data && typeof data === "object" && "error" in data) {
      const candidate = data.error;
      if (typeof candidate === "string" && candidate.trim()) {
        message = candidate;
      }
    } else if (text) {
      message = text;
    }

    throw new Error(message);
  }

  return data as T;
}

function LoadingScreen() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-950 px-4">
      <Card className="w-full max-w-lg">
        <CardHeader className="items-center text-center">
          <LoaderCircle className="h-8 w-8 animate-spin text-cyan-200" />
          <CardTitle>Loading dashboard</CardTitle>
          <CardDescription>Reading the current gateway runtime configuration.</CardDescription>
        </CardHeader>
      </Card>
    </div>
  );
}

function ErrorScreen({ message }: { message: string }) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-950 px-4">
      <Card className="w-full max-w-2xl border-rose-400/30">
        <CardHeader>
          <CardTitle>Dashboard failed to load</CardTitle>
          <CardDescription>{message}</CardDescription>
        </CardHeader>
      </Card>
    </div>
  );
}

export default function App() {
  const [config, setConfig] = useState<DashboardConfig | null>(null);
  const [configError, setConfigError] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string>("");
  const [deviceApprovals, setDeviceApprovals] = useState<DeviceApproval[]>([]);
  const [isLoadingApprovals, setIsLoadingApprovals] = useState(false);
  const [approvalsError, setApprovalsError] = useState<string | null>(null);
  const [approvingRequestId, setApprovingRequestId] = useState<string | null>(null);
  const [busyActionId, setBusyActionId] = useState<string | null>(null);
  const [actionResult, setActionResult] = useState<ActionResult>(null);

  const applyConfig = useCallback((nextConfig: DashboardConfig, preferredViewId = readSelectedView()) => {
    setConfig(nextConfig);
    setConfigError(null);

    const nextView = resolveViewId(nextConfig, preferredViewId);
    setSelectedId(nextView);
    if (nextView) writeSelectedView(nextView);
  }, []);

  useEffect(() => {
    let isMounted = true;

    void fetchJson<DashboardConfig>(CONFIG_ENDPOINT)
      .then((nextConfig) => {
        if (!isMounted) return;
        applyConfig(nextConfig);
      })
      .catch((error: Error) => {
        if (!isMounted) return;
        setConfigError(error.message);
      });

    return () => {
      isMounted = false;
    };
  }, [applyConfig]);

  useEffect(() => {
    function onHashChange() {
      const nextView = readSelectedView();
      if (!config || !nextView) return;
      setSelectedId(resolveViewId(config, nextView));
    }

    window.addEventListener("hashchange", onHashChange);
    return () => {
      window.removeEventListener("hashchange", onHashChange);
    };
  }, [config]);

  const selectView = useCallback((viewId: string) => {
    setSelectedId(viewId);
    writeSelectedView(viewId);
  }, []);

  const refreshApprovals = useCallback(async () => {
    setIsLoadingApprovals(true);
    setApprovalsError(null);

    try {
      const response = await fetchJson<{ requests: DeviceApproval[] }>(DEVICE_APPROVALS_ENDPOINT);
      setDeviceApprovals(Array.isArray(response.requests) ? response.requests : []);
    } catch (error) {
      setApprovalsError(error instanceof Error ? error.message : "Could not load pending device approvals.");
    } finally {
      setIsLoadingApprovals(false);
    }
  }, []);

  const approveRequest = useCallback(
    async (requestId: string) => {
      setApprovingRequestId(requestId);
      setActionResult(null);

      try {
        const response = await fetchJson<{ approvedRequestId: string; deviceId: string }>(
          `${DEVICE_APPROVALS_ENDPOINT}/${encodeURIComponent(requestId)}/approve`,
          { method: "POST" },
        );

        setActionResult({
          kind: "success",
          title: "Device approved",
          detail: `Approved request ${response.approvedRequestId} with device id ${response.deviceId}.`,
        });
        await refreshApprovals();
      } catch (error) {
        setActionResult({
          kind: "error",
          title: "Device approval failed",
          detail: error instanceof Error ? error.message : "Unknown approval error.",
        });
      } finally {
        setApprovingRequestId(null);
      }
    },
    [refreshApprovals],
  );

  const restartOpenClaw = useCallback(async () => {
    setBusyActionId("restart-openclaw");
    setActionResult(null);

    try {
      const response = await fetchJson<{ output: string[] }>(RESTART_ENDPOINT, { method: "POST" });
      setActionResult({
        kind: "success",
        title: "Restart completed",
        detail: response.output.join(" "),
      });
    } catch (error) {
      setActionResult({
        kind: "error",
        title: "Restart failed",
        detail: error instanceof Error ? error.message : "Unknown restart error.",
      });
    } finally {
      setBusyActionId(null);
    }
  }, []);

  const saveToolOrder = useCallback(
    async (toolOrder: string[]) => {
      const response = await fetchJson<PreferencesResponse>(PREFERENCES_ENDPOINT, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ toolOrder }),
      });

      applyConfig(response.config, selectedId);
    },
    [applyConfig, selectedId],
  );

  const selectedTool = useMemo(
    () => config?.tools.find((tool) => tool.id === selectedId) ?? null,
    [config, selectedId],
  );
  const selectedUtility = useMemo(
    () => config?.utilities.find((utility) => utility.id === selectedId) ?? null,
    [config, selectedId],
  );

  useEffect(() => {
    if (!config) return;
    const viewLabel = selectedTool ? selectedTool.tabTitle || selectedTool.label : "Dashboard";
    document.title = composeDocumentTitle(viewLabel, config.tenantLabel, config.titleSuffix);
  }, [config, selectedTool]);

  useEffect(() => {
    if (selectedUtility?.id === "device-approvals") {
      void refreshApprovals();
    }
  }, [refreshApprovals, selectedUtility?.id]);

  if (!config && !configError) return <LoadingScreen />;
  if (!config) return <ErrorScreen message={configError || "Unknown dashboard load error."} />;

  return (
    <AppShell
      brandName={config.brandName}
      tenantLabel={config.tenantLabel}
      titleSuffix={config.titleSuffix}
      title={config.title}
      subtitle={config.subtitle}
      tools={config.tools}
      preferences={config.preferences}
      utilities={config.utilities}
      selectedId={selectedId}
      onSelect={selectView}
      onSaveToolOrder={saveToolOrder}
    >
      {selectedTool ? (
        <ToolFrame
          brandName={config.brandName}
          tool={selectedTool}
          openclawAccessMode={config.openclawAccessMode}
          busyActionId={busyActionId}
          onRestartOpenClaw={restartOpenClaw}
        />
      ) : selectedUtility ? (
        <UtilitiesPanel
          utilities={config.utilities}
          selectedUtilityId={selectedUtility.id}
          deviceApprovals={deviceApprovals}
          isLoadingApprovals={isLoadingApprovals}
          approvalsError={approvalsError}
          approvingRequestId={approvingRequestId}
          busyActionId={busyActionId}
          actionResult={actionResult}
          onRefreshApprovals={refreshApprovals}
          onApproveRequest={approveRequest}
          onRestartOpenClaw={restartOpenClaw}
        />
      ) : (
        <Card>
          <CardHeader>
            <CardTitle>No view selected</CardTitle>
            <CardDescription>Select an app or utility from the sidebar.</CardDescription>
          </CardHeader>
        </Card>
      )}
    </AppShell>
  );
}
