/**
 * CaseService — Facade
 * Single entry point from CaseTriggerHandler.
 * Reads pre-classified domain buckets and delegates to singleton service classes.
 * Execution order is explicit — the order calls appear here IS the order they run.
 *
 * To add new logic:
 *   1. Create a focused singleton service class
 *   2. Add a call here in the right position — nothing else changes
 */
public with sharing class CaseService {

    // ── BEFORE INSERT ─────────────────────────────────────────────────────────
    public static void handleBeforeInsert(CaseDomain domain) {

        if (!domain.cancellationCases.isEmpty())
            CaseFlightDisruptionService.getInstance().setDefaultResolution(domain.cancellationCases);

        if (!domain.flightDisruptionCases.isEmpty())
            CaseFlightDisruptionService.getInstance().applyFlightDisruptionDefaults(domain.flightDisruptionCases);
    }

    // ── BEFORE UPDATE ─────────────────────────────────────────────────────────
    public static void handleBeforeUpdate(CaseDomain domain) {

        if (!domain.cancellationCases.isEmpty())
            CaseFlightDisruptionService.getInstance().setDefaultResolution(domain.cancellationCases);
    }

    // ── AFTER INSERT ──────────────────────────────────────────────────────────
    public static void handleAfterInsert(CaseDomain domain) {

        if (!domain.flightDisruptionCases.isEmpty())
            CaseNotificationService.getInstance().notifyOperationsTeam(domain.flightDisruptionCases);
    }

    // ── AFTER UPDATE ──────────────────────────────────────────────────────────
    public static void handleAfterUpdate(CaseDomain domain) {

        if (!domain.statusChangedCases.isEmpty())
            CaseStatusService.getInstance().onStatusChanged(domain.statusChangedCases);

    }
}