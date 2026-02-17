// STEP LABELS
import STEP_PROJECT_SETUP from '@salesforce/label/c.Main_Step_ProjectSetup';
import STEP_DATA_SOURCE from '@salesforce/label/c.Main_Step_DataSource';
import STEP_FIELD_MAPPING from '@salesforce/label/c.Main_Step_FieldMapping';
import STEP_TRANSFORMATIONS from '@salesforce/label/c.Main_Step_Transformations';
import STEP_VALIDATION from '@salesforce/label/c.Main_Step_Validation';
import STEP_EXECUTION from '@salesforce/label/c.Main_Step_Execution';

// MESSAGES
import MSG_ALL_FIELDS_REQUIRED from '@salesforce/label/c.Main_Message_AllFieldsRequired';
import MSG_PROJECT_EXISTS from '@salesforce/label/c.Main_Message_ProjectExists';
import MSG_PROJECT_CREATED from '@salesforce/label/c.Main_Message_ProjectCreated';
import MSG_ERROR_OCCURRED from '@salesforce/label/c.Main_Message_ErrorOccurred';
import MSG_SELECT_PROJECT_FIRST from '@salesforce/label/c.Main_Message_SelectProjectFirst';
import MSG_CREATE_PROJECT_FIRST from '@salesforce/label/c.Main_Message_CreateProjectFirst';
import MSG_IMPORT_STARTED from '@salesforce/label/c.Main_Message_ImportStarted';
import MSG_LOGS_COMING_SOON from '@salesforce/label/c.Main_Message_Logs_Coming_Soon';
import MSG_SETTINGS_COMING_SOON from '@salesforce/label/c.Main_Message_SETTINGS_COMING_SOON';
import MSG_VIEW_LOGS from '@salesforce/label/c.Main_Message_VIEW_LOGS';
import MSG_EXPORT_COMING_SOON from '@salesforce/label/c.Main_Message_EXPORT_COMING_SOON';

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
  { number: 1, label: STEP_PROJECT_SETUP, hasLine: true },
  { number: 2, label: STEP_DATA_SOURCE, hasLine: true },
  { number: 3, label: STEP_FIELD_MAPPING, hasLine: true },
  { number: 4, label:  STEP_TRANSFORMATIONS, hasLine: true },
  { number: 5, label: STEP_VALIDATION, hasLine: true },
  { number: 6, label:  STEP_EXECUTION, hasLine: false }
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
  ANALYTICS: "analytics",
  EXECUTION_HISTORY: "executionHistory"
};

// Messages
export const MESSAGES = {
  ALL_FIELDS_REQUIRED: MSG_ALL_FIELDS_REQUIRED,
  PROJECT_EXISTS: MSG_PROJECT_EXISTS,
  PROJECT_CREATED: MSG_PROJECT_CREATED,
  ERROR_OCCURRED: MSG_ERROR_OCCURRED,
  SELECT_PROJECT_FIRST: MSG_SELECT_PROJECT_FIRST,
  CREATE_PROJECT_FIRST: MSG_CREATE_PROJECT_FIRST,
  IMPORT_STARTED: MSG_IMPORT_STARTED,
  LOGS_COMING_SOON: MSG_LOGS_COMING_SOON,
  SETTINGS_COMING_SOON: MSG_SETTINGS_COMING_SOON,
  VIEW_LOGS: MSG_VIEW_LOGS,
  EXPORT_COMING_SOON: MSG_EXPORT_COMING_SOON
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