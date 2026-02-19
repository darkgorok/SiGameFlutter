const e2eBypassProfileUpsert = bool.fromEnvironment(
  'E2E_BYPASS_PROFILE_UPSERT',
  defaultValue: false,
);

const e2eAutoFlowEnabled = bool.fromEnvironment(
  'E2E_AUTO_FLOW',
  defaultValue: false,
);
