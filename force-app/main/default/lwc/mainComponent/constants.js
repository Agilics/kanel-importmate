import  EditProject_Modal_Title from '@salesforce/label/c.EditProject_Modal_Title';
import ALL_FIELDS_REQUIRED    from '@salesforce/label/c.ALL_FIELDS_REQUIRED';
import PROJECT_EXISTS          from '@salesforce/label/c.PROJECT_EXISTS';
import PROJECT_CREATED         from '@salesforce/label/c.PROJECT_CREATED';
import ERROR_OCCURRED          from '@salesforce/label/c.ERROR_OCCURRED';
import SELECT_PROJECT_FIRST    from '@salesforce/label/c.SELECT_PROJECT_FIRST';
import CREATE_PROJECT_FIRST    from '@salesforce/label/c.CREATE_PROJECT_FIRST';
import IMPORT_STARTED          from '@salesforce/label/c.IMPORT_STARTED';
import LOGS_COMING_SOON        from '@salesforce/label/c.LOGS_COMING_SOON';
import SETTINGS_COMING_SOON    from '@salesforce/label/c.SETTINGS_COMING_SOON';
import VIEW_LOGS               from '@salesforce/label/c.VIEW_LOGS';
import EXPORT_COMING_SOON      from '@salesforce/label/c.EXPORT_COMING_SOON'; 
import ANALYTICS_COMING_SOON   from '@salesforce/label/c.ANALYTICS_COMING_SOON';
import SEARCH_PROJECTS_FEATURE from '@salesforce/label/c.SEARCH_PROJECTS_FEATURE';
import UNSAVED_CHANGES_WARNING from '@salesforce/label/c.UNSAVED_CHANGES_WARNING';

// Step constants
export const STEPS = {
  //DASHBOARD: 0,
  PROJECT_SETUP  : 1,
  DATA_SOURCE    : 2,
  FIELD_MAPPING  : 3,
  TRANSFORMATIONS: 4,
  VALIDATION     : 5,
  EXECUTION      : 6
};

// Step configuration
export const STEP_CONFIG = [
  { number: 1, label: 'Project Setup',    hasLine: true  },
  { number: 2, label: 'Data Source',      hasLine: true  },
  { number: 3, label: 'Field Mapping',    hasLine: true  },
  { number: 4, label: 'Transformations',  hasLine: true  },
  { number: 5, label: 'Validation',       hasLine: true  },
  { number: 6, label: 'Execution',        hasLine: false }
];

// Page constants
export const PAGES = {
  DASHBOARD: 'dashboard',
  PROJECTS : 'projects',
  LOGS     : 'logs',
  SETTINGS : 'settings'
};

// Quick Actions
export const QUICK_ACTIONS = {
  NEW_PROJECT      : 'newProject',
  VIEW_LOGS        : 'viewLogs',
  EXPORT_DATA      : 'exportData',
  RECENT_PROJECTS  : 'recentProjects',
  IMPORT_TEMPLATES : 'importTemplates',
  ANALYTICS        : 'analytics',
  EXECUTION_HISTORY: 'executionHistory'
};

// Messages
// Les labels avec {0}, {1} sont des strings avec placeholders :
// Salesforce ne les remplace pas automatiquement,
// le remplacement se fait toujours avec .replace('{0}', value) dans le JS.
export const MESSAGES = {
    ALL_FIELDS_REQUIRED    : ALL_FIELDS_REQUIRED,
    PROJECT_EXISTS         : PROJECT_EXISTS,
    PROJECT_CREATED        : PROJECT_CREATED,
    ERROR_OCCURRED         : ERROR_OCCURRED,
    SELECT_PROJECT_FIRST   : SELECT_PROJECT_FIRST,
    CREATE_PROJECT_FIRST   : CREATE_PROJECT_FIRST,
    IMPORT_STARTED         : IMPORT_STARTED,
    LOGS_COMING_SOON       : LOGS_COMING_SOON,
    SETTINGS_COMING_SOON   : SETTINGS_COMING_SOON,
    VIEW_LOGS              : VIEW_LOGS,
    EXPORT_COMING_SOON     : EXPORT_COMING_SOON,
    ANALYTICS_COMING_SOON  : ANALYTICS_COMING_SOON,
    SEARCH_PROJECTS_FEATURE: SEARCH_PROJECTS_FEATURE,
    UNSAVED_CHANGES_WARNING: UNSAVED_CHANGES_WARNING
};

// Toast variants
export const TOAST_VARIANTS = {
  SUCCESS: 'success',
  ERROR  : 'error',
  WARNING: 'warning',
  INFO   : 'info'
};

// Project field names
export const PROJECT_FIELD_NAMES = {
  TARGET_OBJECT: ['TargetObject__c']
};

export const PROJECT_MODAL_EDIT_TITLE =EditProject_Modal_Title;

// Recent projects limit
export const RECENT_PROJECTS_LIMIT = 3;