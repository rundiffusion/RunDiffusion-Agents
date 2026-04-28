import { useEffect, useMemo, useState, type ReactNode } from "react";
import {
  ArrowDown,
  ArrowUp,
  Check,
  ChevronRight,
  CircleUserRound,
  LayoutGrid,
  RotateCcw,
  SlidersHorizontal,
  Wrench,
  X,
} from "lucide-react";

import { cn } from "../lib/utils";
import { Button } from "./ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "./ui/dialog";

const BRAND_LOGO_PATH = `${import.meta.env.BASE_URL}rundiffusion-agents-logo.png`;

type NavigationItem = {
  id: string;
  label: string;
  description: string;
  enabled?: boolean;
};

type ToolOrderPreferences = {
  toolOrder: string[];
  defaultToolOrder: string[];
};

type AppShellProps = {
  brandName: string;
  tenantLabel: string;
  titleSuffix: string;
  title: string;
  subtitle: string;
  tools: NavigationItem[];
  preferences: ToolOrderPreferences;
  utilities: NavigationItem[];
  selectedId: string;
  onSelect: (id: string) => void;
  onSaveToolOrder: (toolOrder: string[]) => Promise<void>;
  children: ReactNode;
};

function orderedVisibleTools(tools: NavigationItem[], order: string[]) {
  const toolById = new Map(tools.map((tool) => [tool.id, tool]));
  const seenIds = new Set<string>();
  const orderedTools: NavigationItem[] = [];

  for (const id of order) {
    const tool = toolById.get(id);
    if (!tool || seenIds.has(id)) continue;
    seenIds.add(id);
    orderedTools.push(tool);
  }

  for (const tool of tools) {
    if (!seenIds.has(tool.id)) {
      orderedTools.push(tool);
    }
  }

  return orderedTools;
}

function mergeVisibleOrder(fullOrder: string[], visibleOrder: string[], defaultOrder: string[]) {
  const defaultIds = new Set(defaultOrder);
  const visibleIds = new Set(visibleOrder);
  const nextOrder: string[] = [];
  const seenIds = new Set<string>();
  const baseOrder = fullOrder.length ? fullOrder : defaultOrder;
  let visibleIndex = 0;

  for (const id of baseOrder) {
    if (!defaultIds.has(id) || seenIds.has(id)) continue;

    if (visibleIds.has(id)) {
      const replacement = visibleOrder[visibleIndex];
      visibleIndex += 1;
      if (replacement && defaultIds.has(replacement) && !seenIds.has(replacement)) {
        nextOrder.push(replacement);
        seenIds.add(replacement);
      }
      continue;
    }

    nextOrder.push(id);
    seenIds.add(id);
  }

  for (const id of visibleOrder) {
    if (defaultIds.has(id) && !seenIds.has(id)) {
      nextOrder.push(id);
      seenIds.add(id);
    }
  }

  for (const id of defaultOrder) {
    if (!seenIds.has(id)) {
      nextOrder.push(id);
    }
  }

  return nextOrder;
}

function moveItem(items: string[], index: number, direction: -1 | 1) {
  const nextIndex = index + direction;
  if (nextIndex < 0 || nextIndex >= items.length) return items;
  const nextItems = [...items];
  const [item] = nextItems.splice(index, 1);
  nextItems.splice(nextIndex, 0, item);
  return nextItems;
}

function AppOrderDialog({
  tools,
  preferences,
  onSaveToolOrder,
}: {
  tools: NavigationItem[];
  preferences: ToolOrderPreferences;
  onSaveToolOrder: (toolOrder: string[]) => Promise<void>;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [draftOrder, setDraftOrder] = useState<string[]>([]);
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [shouldSaveDefaultOrder, setShouldSaveDefaultOrder] = useState(false);
  const toolsById = useMemo(() => new Map(tools.map((tool) => [tool.id, tool])), [tools]);
  const draftTools = draftOrder
    .map((id) => toolsById.get(id))
    .filter((tool): tool is NavigationItem => Boolean(tool));

  useEffect(() => {
    if (!isOpen) return;
    setDraftOrder(orderedVisibleTools(tools, preferences.toolOrder).map((tool) => tool.id));
    setSaveError(null);
    setShouldSaveDefaultOrder(false);
  }, [isOpen, preferences.toolOrder, tools]);

  const resetOrder = () => {
    setDraftOrder(orderedVisibleTools(tools, preferences.defaultToolOrder).map((tool) => tool.id));
    setSaveError(null);
    setShouldSaveDefaultOrder(true);
  };

  const saveOrder = async () => {
    setIsSaving(true);
    setSaveError(null);

    try {
      await onSaveToolOrder(
        shouldSaveDefaultOrder
          ? preferences.defaultToolOrder
          : mergeVisibleOrder(preferences.toolOrder, draftOrder, preferences.defaultToolOrder),
      );
      setIsOpen(false);
    } catch (error) {
      setSaveError(error instanceof Error ? error.message : "Could not save app order.");
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" className="h-8 px-2.5">
          <SlidersHorizontal className="h-4 w-4" />
          Order
        </Button>
      </DialogTrigger>
      <DialogContent className="w-[min(520px,calc(100vw-2rem))]">
        <DialogHeader className="border-b border-zinc-800/80 pb-5 pr-20">
          <DialogTitle>App order</DialogTitle>
          <DialogDescription>Saved for this tenant.</DialogDescription>
        </DialogHeader>

        <div className="space-y-2 overflow-y-auto px-6 py-5">
          {draftTools.map((tool, index) => (
            <div
              key={tool.id}
              className="flex items-center justify-between gap-3 rounded-xl border border-zinc-800/80 bg-zinc-900/55 px-3 py-3"
            >
              <div className="min-w-0">
                <div className="truncate text-sm font-medium text-zinc-50">{tool.label}</div>
                <div className="mt-0.5 truncate text-xs text-zinc-500">{tool.description}</div>
              </div>
              <div className="flex shrink-0 items-center gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="h-9 w-9 px-0"
                  onClick={() => {
                    setShouldSaveDefaultOrder(false);
                    setDraftOrder((current) => moveItem(current, index, -1));
                  }}
                  disabled={index === 0 || isSaving}
                  aria-label={`Move ${tool.label} up`}
                  title={`Move ${tool.label} up`}
                >
                  <ArrowUp className="h-4 w-4" />
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="h-9 w-9 px-0"
                  onClick={() => {
                    setShouldSaveDefaultOrder(false);
                    setDraftOrder((current) => moveItem(current, index, 1));
                  }}
                  disabled={index === draftTools.length - 1 || isSaving}
                  aria-label={`Move ${tool.label} down`}
                  title={`Move ${tool.label} down`}
                >
                  <ArrowDown className="h-4 w-4" />
                </Button>
              </div>
            </div>
          ))}

          {saveError ? (
            <div className="rounded-xl border border-rose-400/30 bg-rose-400/10 px-3 py-3 text-sm text-rose-100">
              {saveError}
            </div>
          ) : null}
        </div>

        <DialogFooter className="border-t border-zinc-800/80 pt-5">
          <Button type="button" variant="ghost" onClick={resetOrder} disabled={isSaving}>
            <RotateCcw className="h-4 w-4" />
            Reset
          </Button>
          <DialogClose asChild>
            <Button type="button" variant="outline" disabled={isSaving}>
              <X className="h-4 w-4" />
              Cancel
            </Button>
          </DialogClose>
          <Button type="button" onClick={() => void saveOrder()} disabled={isSaving}>
            <Check className="h-4 w-4" />
            {isSaving ? "Saving" : "Save"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function NavigationSection({
  icon,
  label,
  items,
  selectedId,
  onSelect,
  action,
  compact = false,
}: {
  icon: ReactNode;
  label: string;
  items: NavigationItem[];
  selectedId: string;
  onSelect: (id: string) => void;
  action?: ReactNode;
  compact?: boolean;
}) {
  return (
    <section className="space-y-3">
      <div className="flex items-center justify-between gap-3 px-2">
        <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.22em] text-zinc-500">
          {icon}
          <span>{label}</span>
        </div>
        {action ? <div className="shrink-0">{action}</div> : null}
      </div>
      <div className="space-y-1.5">
        {items.map((item) => {
          const isSelected = item.id === selectedId;
          const isDisabled = item.enabled === false;

          return (
            <button
              key={item.id}
              type="button"
              onClick={() => onSelect(item.id)}
              className={cn(
                "flex w-full cursor-pointer items-start justify-between gap-3 rounded-2xl border px-3 text-left transition-colors",
                compact ? "py-2.5" : "py-3",
                isSelected
                  ? "border-cyan-400/30 bg-cyan-400/10 text-zinc-50"
                  : "border-transparent bg-zinc-950/30 text-zinc-300 hover:border-zinc-800 hover:bg-zinc-900/70",
              )}
            >
              <div className="min-w-0">
                <div className="truncate text-sm font-medium">{item.label}</div>
                {!compact ? (
                  <div className="mt-1 text-xs leading-5 text-zinc-500">{item.description}</div>
                ) : null}
              </div>
              <div className="mt-0.5 flex shrink-0 items-center gap-2">
                {isDisabled ? (
                  <span className="rounded-full border border-zinc-800 px-2 py-0.5 text-[10px] uppercase tracking-[0.2em] text-zinc-500">
                    Off
                  </span>
                ) : null}
                <ChevronRight className="h-4 w-4 text-zinc-600" />
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}

export function AppShell({
  brandName,
  tenantLabel,
  titleSuffix,
  title,
  subtitle,
  tools,
  preferences,
  utilities,
  selectedId,
  onSelect,
  onSaveToolOrder,
  children,
}: AppShellProps) {
  return (
    <div className="h-screen overflow-hidden bg-[radial-gradient(circle_at_top,_rgba(34,211,238,0.18),_transparent_28%),linear-gradient(180deg,_#111827_0%,_#09090b_38%,_#020617_100%)] text-zinc-50">
      <div className="mx-auto flex h-full w-full max-w-[1800px] gap-6 px-4 py-4 lg:px-6">
        <aside className="flex h-full w-full max-w-sm min-h-0 flex-col rounded-[28px] border border-zinc-800/80 bg-zinc-950/70 p-4 shadow-[0_24px_80px_-36px_rgba(0,0,0,0.85)] backdrop-blur lg:max-w-[320px]">
          <div className="rounded-3xl border border-zinc-800 bg-zinc-950/80 p-4">
            <div className="flex items-center gap-3">
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2 text-xs font-semibold uppercase tracking-[0.24em]">
                  <span className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-cyan-400/35 bg-cyan-400/12 text-cyan-100">
                    <CircleUserRound className="h-4 w-4" />
                  </span>
                  <span className="text-zinc-500">{tenantLabel}</span>
                </div>
              </div>
            </div>
            <h1 className="mt-3 text-2xl font-semibold tracking-tight">{title}</h1>
            <p className="mt-2 text-sm leading-6 text-zinc-400">{subtitle}</p>
            <div className="mt-3 flex items-center gap-2 text-xs uppercase tracking-[0.22em] text-zinc-500">
              <img src={BRAND_LOGO_PATH} alt="" aria-hidden="true" className="h-4 w-4 shrink-0" />
              <span>{titleSuffix}</span>
            </div>
          </div>

          <div className="mt-6 min-h-0 flex-1 space-y-6 overflow-y-auto pr-1">
            <NavigationSection
              icon={<LayoutGrid className="h-4 w-4" />}
              label="Apps"
              items={tools}
              selectedId={selectedId}
              onSelect={onSelect}
              action={
                <AppOrderDialog
                  tools={tools}
                  preferences={preferences}
                  onSaveToolOrder={onSaveToolOrder}
                />
              }
            />
          </div>

          <div className="mt-4 border-t border-zinc-900 pt-4">
            <NavigationSection
              icon={<Wrench className="h-4 w-4" />}
              label="Utilities"
              items={utilities}
              selectedId={selectedId}
              onSelect={onSelect}
              compact
            />

            <div className="mt-4 border-t border-zinc-900/80 pt-4">
              <a
                href="https://www.rundiffusion.com?utm_source=agents-dashboard&utm_medium=product&utm_campaign=run-diffusion-agents&utm_content=sidebar-brand-link"
                target="_blank"
                rel="noreferrer"
                className="flex items-center gap-2 text-sm font-medium text-zinc-300 transition-colors hover:text-zinc-50"
              >
                <img src={BRAND_LOGO_PATH} alt="" aria-hidden="true" className="h-5 w-5 shrink-0" />
                <span>RunDiffusion.com Agents</span>
              </a>
            </div>
          </div>
        </aside>

        <main className="min-w-0 min-h-0 flex-1 overflow-hidden">{children}</main>
      </div>
    </div>
  );
}
