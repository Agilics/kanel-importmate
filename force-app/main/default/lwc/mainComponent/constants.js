// Step constants
export const STEPS = {
  //DASHBOARD: 0,
  PROJECT_SETUP: 1,
  DATA_SOURCE: 2,
  FIELD_MAPPING: 3,
  TRANSFORMATIONS: 4,
  VALIDATION: 5,
  EXECUTION: 6
};

// Step configuration
export const STEP_CONFIG = [
  { number: 1, label: "Project Setup", hasLine: true },
  { number: 2, label: "Data Source", hasLine: true },
  { number: 3, label: "Field Mapping", hasLine: true },
  { number: 4, label: "Transformations", hasLine: true },
  { number: 5, label: "Validation", hasLine: true },
  { number: 6, label: "Execution", hasLine: false }
];

// Page constants
export const PAGES = {
  DASHBOARD: "dashboard",
  PROJECTS: "projects",
  LOGS: "logs",
  SETTINGS: "settings"
};

// Quick Actions
export const QUICK_ACTIONS = {
  NEW_PROJECT: "newProject",
  VIEW_LOGS: "viewLogs",
  EXPORT_DATA: "exportData",
  RECENT_PROJECTS: "recentProjects",
  IMPORT_TEMPLATES: "importTemplates",
  ANALYTICS: "analytics"
};

// Messages
export const MESSAGES = {
  ALL_FIELDS_REQUIRED: "All fields are required",
  PROJECT_EXISTS: "A project with this name and target object already exists",
  PROJECT_CREATED: "Project created successfully with ID: {0}",
  ERROR_OCCURRED: "An error occurred",
  SELECT_PROJECT_FIRST: "Please select or create a project first",
  CREATE_PROJECT_FIRST: "Please create a project first",
  IMPORT_STARTED: "Import started in {0} mode with batch size {1}",
  LOGS_COMING_SOON: "Logs feature coming soon",
  SETTINGS_COMING_SOON: "Settings feature coming soon",
  VIEW_LOGS: "Viewing logs",
  EXPORT_COMING_SOON: "Export feature coming soon"
};

// Toast variants
export const TOAST_VARIANTS = {
  SUCCESS: "success",
  ERROR: "error",
  WARNING: "warning",
  INFO: "info"
};

// Project field names
export const PROJECT_FIELD_NAMES = {
  TARGET_OBJECT: [
    "TargetObject__c"
  ]
};

// Recent projects limit
export const RECENT_PROJECTS_LIMIT = 3;