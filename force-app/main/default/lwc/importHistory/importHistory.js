import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExecutionHistoryLive from '@salesforce/apex/DashboardController.getExecutionHistoryLive';
import deleteExecutionHistory from '@salesforce/apex/DashboardController.deleteExecutionHistory';
import deleteExecutionHistories from '@salesforce/apex/DashboardController.deleteExecutionHistories';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

// ─── Custom Labels ─────────────────────────────────────────────────────────────
import LBL_TITLE                   from '@salesforce/label/c.IH_Title';
import LBL_SUBTITLE                from '@salesforce/label/c.IH_Subtitle';
import LBL_EXPORT_REPORT           from '@salesforce/label/c.IH_ExportReport';
import LBL_NEW_IMPORT_PROJECT      from '@salesforce/label/c.IH_NewImportProject';

import LBL_FILTER_STATUS           from '@salesforce/label/c.IH_Filter_Status';
import LBL_FILTER_DATE_RANGE       from '@salesforce/label/c.IH_Filter_DateRange';
import LBL_FILTER_PROJECT          from '@salesforce/label/c.IH_Filter_Project';
import LBL_FILTER_TARGET_OBJECT    from '@salesforce/label/c.IH_Filter_TargetObject';
import LBL_APPLY_FILTERS           from '@salesforce/label/c.IH_ApplyFilters';

import LBL_STATUS_ALL              from '@salesforce/label/c.IH_Status_All';
import LBL_STATUS_COMPLETED        from '@salesforce/label/c.IH_Status_Completed';
import LBL_STATUS_RUNNING          from '@salesforce/label/c.IH_Status_Running';
import LBL_STATUS_FAILED           from '@salesforce/label/c.IH_Status_Failed';
import LBL_STATUS_CANCELLED        from '@salesforce/label/c.IH_Status_Cancelled';
import LBL_STATUS_DRAFT            from '@salesforce/label/c.IH_Status_Draft';

import LBL_DATE_LAST7              from '@salesforce/label/c.IH_Date_Last7';
import LBL_DATE_LAST30             from '@salesforce/label/c.IH_Date_Last30';
import LBL_DATE_LAST90             from '@salesforce/label/c.IH_Date_Last90';
import LBL_DATE_ALL_TIME           from '@salesforce/label/c.IH_Date_AllTime';

import LBL_ALL_PROJECTS            from '@salesforce/label/c.IH_AllProjects';
import LBL_ALL_OBJECTS             from '@salesforce/label/c.IH_AllObjects';

import LBL_KPI_TOTAL_EXECUTIONS    from '@salesforce/label/c.IH_KPI_TotalExecutions';
import LBL_KPI_SUCCESS_RATE        from '@salesforce/label/c.IH_KPI_SuccessRate';
import LBL_KPI_RECORDS_PROCESSED   from '@salesforce/label/c.IH_KPI_RecordsProcessed';
import LBL_KPI_AVG_DURATION        from '@salesforce/label/c.IH_KPI_AvgDuration';

import LBL_TABLE_TITLE             from '@salesforce/label/c.IH_Table_Title';
import LBL_TABLE_SEARCH            from '@salesforce/label/c.IH_Table_SearchPlaceholder';
import LBL_TABLE_COL_PROJECT       from '@salesforce/label/c.IH_Table_ColProject';
import LBL_TABLE_COL_STATUS        from '@salesforce/label/c.IH_Table_ColStatus';
import LBL_TABLE_COL_TARGET        from '@salesforce/label/c.IH_Table_ColTargetObject';
import LBL_TABLE_COL_RECORDS       from '@salesforce/label/c.IH_Table_ColRecords';
import LBL_TABLE_COL_DURATION      from '@salesforce/label/c.IH_Table_ColDuration';
import LBL_TABLE_COL_STARTED       from '@salesforce/label/c.IH_Table_ColStarted';
import LBL_TABLE_COL_ACTIONS       from '@salesforce/label/c.IH_Table_ColActions';
import LBL_TABLE_EMPTY             from '@salesforce/label/c.IH_Table_Empty';
import LBL_TABLE_SHOWING           from '@salesforce/label/c.IH_Table_Showing';

import LBL_ACTION_VIEW             from '@salesforce/label/c.IH_Action_View';
import LBL_ACTION_MONITOR          from '@salesforce/label/c.IH_Action_Monitor';
import LBL_ACTION_DEBUG            from '@salesforce/label/c.IH_Action_Debug';
import LBL_ACTION_DELETE_SELECTED  from '@salesforce/label/c.IH_Action_DeleteSelected';

import LBL_MODAL_CREATE_TITLE      from '@salesforce/label/c.IH_Modal_CreateTitle';
import LBL_MODAL_EXPORT_EXEC       from '@salesforce/label/c.IH_Modal_ExportExecution';
import LBL_MODAL_DELETE_EXEC       from '@salesforce/label/c.IH_Modal_DeleteExecution';
import LBL_MODAL_EXEC_DETAILS      from '@salesforce/label/c.IH_Modal_ExecutionDetails';
import LBL_MODAL_RECORDS           from '@salesforce/label/c.IH_Modal_Records';
import LBL_DETAIL_TARGET_OBJECT    from '@salesforce/label/c.IH_Detail_TargetObject';
import LBL_DETAIL_STATUS           from '@salesforce/label/c.IH_Detail_Status';
import LBL_DETAIL_PHASE            from '@salesforce/label/c.IH_Detail_Phase';
import LBL_DETAIL_STARTED          from '@salesforce/label/c.IH_Detail_Started';
import LBL_DETAIL_DURATION         from '@salesforce/label/c.IH_Detail_Duration';
import LBL_DETAIL_PROCESSED        from '@salesforce/label/c.IH_Detail_Processed';
import LBL_DETAIL_TOTAL            from '@salesforce/label/c.IH_Detail_Total';
import LBL_DETAIL_FAILED           from '@salesforce/label/c.IH_Detail_Failed';
import LBL_DETAIL_SUCCESS          from '@salesforce/label/c.IH_Detail_Success';
import LBL_DETAIL_REMAINING        from '@salesforce/label/c.IH_Detail_Remaining';
import LBL_DETAIL_RECORDS_SUMMARY  from '@salesforce/label/c.IH_Detail_RecordsSummary';

import LBL_TOAST_ERROR_LOADING     from '@salesforce/label/c.IH_Toast_ErrorLoadingHistory';
import LBL_TOAST_SELECT_ONE        from '@salesforce/label/c.IH_Toast_SelectAtLeastOne';
import LBL_CONFIRM_DELETE_MULTI    from '@salesforce/label/c.IH_Confirm_DeleteMultiple';
import LBL_TOAST_ERR_DEL_SELECTED  from '@salesforce/label/c.IH_Toast_ErrorDeleteSelected';
import LBL_TOAST_CANNOT_DEL_RUN    from '@salesforce/label/c.IH_Toast_CannotDeleteRunning';
import LBL_CONFIRM_DELETE_SINGLE   from '@salesforce/label/c.IH_Confirm_DeleteSingle';
import LBL_TOAST_DELETE_SUCCESS    from '@salesforce/label/c.IH_Toast_DeleteSuccess';
import LBL_TOAST_ERR_DEL_SINGLE    from '@salesforce/label/c.IH_Toast_ErrorDeleteSingle';
import LBL_TOAST_NOTHING_EXPORT    from '@salesforce/label/c.IH_Toast_NothingToExport';
import LBL_TOAST_NO_EXEC_SELECTED  from '@salesforce/label/c.IH_Toast_NoExecutionSelected';
import LBL_TOAST_PROJECT_CREATED   from '@salesforce/label/c.IH_Toast_ProjectCreated';
import LBL_TOAST_PROJECT_CREATED_MSG from '@salesforce/label/c.IH_Toast_ProjectCreatedMsg';
import LBL_TOAST_ERR_EXPORT_CSV    from '@salesforce/label/c.IH_Toast_ErrorExportCsv';
import LBL_TOAST_EXEC_ID_MISSING   from '@salesforce/label/c.IH_Toast_ExecutionIdMissing';
import LBL_TOAST_ERR_LOAD_DETAILS  from '@salesforce/label/c.IH_Toast_ErrorLoadDetails';

import LBL_TIME_JUST_NOW           from '@salesforce/label/c.IH_Time_JustNow';
import LBL_TIME_1MIN_AGO           from '@salesforce/label/c.IH_Time_1MinuteAgo';
import LBL_TIME_X_MIN_AGO          from '@salesforce/label/c.IH_Time_XMinutesAgo';
import LBL_TIME_1HOUR_AGO          from '@salesforce/label/c.IH_Time_1HourAgo';
import LBL_TIME_X_HOURS_AGO        from '@salesforce/label/c.IH_Time_XHoursAgo';
import LBL_TIME_1DAY_AGO           from '@salesforce/label/c.IH_Time_1DayAgo';
import LBL_TIME_X_DAYS_AGO         from '@salesforce/label/c.IH_Time_XDaysAgo';

import LBL_PHASE_PREFIX            from '@salesforce/label/c.IH_PhasePrefix';
import LBL_PHASE_NA                from '@salesforce/label/c.IH_PhaseNA';
import LBL_EXECUTION_LABEL         from '@salesforce/label/c.IH_ExecutionLabel';
// ────────────────────────────────────────────────────────────────────────────────

const PAGE_SIZE = 5;
const POLLING_FALLBACK_INTERVAL_MS = 30000;
const EVENT_REFRESH_DEBOUNCE_MS = 800;

export default class ImportHistory extends LightningElement {
  @track executions = [];
  @track filteredRows = [];
  @track pageRows = [];

  @track showCreateModal = false;
  @track showViewModal = false;
  @track selectedRow = null;
  @track selectedExecutionIds = [];

  // ─── Expose labels to the template ──────────────────────────────────────────
  label = {
    title:              LBL_TITLE,
    subtitle:           LBL_SUBTITLE,
    exportReport:       LBL_EXPORT_REPORT,
    newImportProject:   LBL_NEW_IMPORT_PROJECT,
    filterStatus:       LBL_FILTER_STATUS,
    filterDateRange:    LBL_FILTER_DATE_RANGE,
    filterProject:      LBL_FILTER_PROJECT,
    filterTargetObject: LBL_FILTER_TARGET_OBJECT,
    applyFilters:       LBL_APPLY_FILTERS,
    kpiTotalExecutions: LBL_KPI_TOTAL_EXECUTIONS,
    kpiSuccessRate:     LBL_KPI_SUCCESS_RATE,
    kpiRecordsProcessed:LBL_KPI_RECORDS_PROCESSED,
    kpiAvgDuration:     LBL_KPI_AVG_DURATION,
    tableTitle:         LBL_TABLE_TITLE,
    tableSearch:        LBL_TABLE_SEARCH,
    tableColProject:    LBL_TABLE_COL_PROJECT,
    tableColStatus:     LBL_TABLE_COL_STATUS,
    tableColTarget:     LBL_TABLE_COL_TARGET,
    tableColRecords:    LBL_TABLE_COL_RECORDS,
    tableColDuration:   LBL_TABLE_COL_DURATION,
    tableColStarted:    LBL_TABLE_COL_STARTED,
    tableColActions:    LBL_TABLE_COL_ACTIONS,
    tableEmpty:         LBL_TABLE_EMPTY,
    modalCreateTitle:   LBL_MODAL_CREATE_TITLE,
    modalExportExec:    LBL_MODAL_EXPORT_EXEC,
    modalDeleteExec:    LBL_MODAL_DELETE_EXEC,
    modalExecDetails:   LBL_MODAL_EXEC_DETAILS,
    modalRecords:       LBL_MODAL_RECORDS,
    detailTargetObject: LBL_DETAIL_TARGET_OBJECT,
    detailStatus:       LBL_DETAIL_STATUS,
    detailPhase:        LBL_DETAIL_PHASE,
    detailStarted:      LBL_DETAIL_STARTED,
    detailDuration:     LBL_DETAIL_DURATION,
    detailProcessed:    LBL_DETAIL_PROCESSED,
    detailTotal:        LBL_DETAIL_TOTAL,
    detailFailed:       LBL_DETAIL_FAILED,
    detailSuccess:      LBL_DETAIL_SUCCESS,
    detailRemaining:    LBL_DETAIL_REMAINING,
    detailRecordsSummary: LBL_DETAIL_RECORDS_SUMMARY
  };
  // ────────────────────────────────────────────────────────────────────────────

  statusFilter = 'all';
  dateRangeFilter = 'all';
  projectFilter = 'all';
  targetFilter = 'all';
  searchTerm = '';

  get statusOptions() {
    return [
      { label: LBL_STATUS_ALL,       value: 'all' },
      { label: LBL_STATUS_COMPLETED, value: 'Completed' },
      { label: LBL_STATUS_RUNNING,   value: 'Running' },
      { label: LBL_STATUS_FAILED,    value: 'Failed' },
      { label: LBL_STATUS_CANCELLED, value: 'Cancelled' },
      { label: LBL_STATUS_DRAFT,     value: 'Draft' }
    ];
  }

  get dateRangeOptions() {
    return [
      { label: LBL_DATE_LAST7,    value: '7' },
      { label: LBL_DATE_LAST30,   value: '30' },
      { label: LBL_DATE_LAST90,   value: '90' },
      { label: LBL_DATE_ALL_TIME, value: 'all' }
    ];
  }

  projectOptions = [{ label: LBL_ALL_PROJECTS, value: 'all' }];
  targetOptions  = [{ label: LBL_ALL_OBJECTS,  value: 'all' }];

  currentPage = 1;
  pageSize = PAGE_SIZE;
  totalExecutions = 0;
  successRateDisplay = '0%';
  recordsProcessedDisplay = '0';
  avgDurationDisplay = '0m';
  liveRefreshTimer;
  isLoadingData = false;
  isDeleting = false;
  eventRefreshTimer = null;
  subscription = null;
  channelName = '/event/ImportStatusEvent__e';

  connectedCallback() {
    this.registerEmpErrorListener();
    this.loadData();
    this.handleSubscribe();
    this.startLiveRefresh();
  }

  disconnectedCallback() {
    this.handleUnsubscribe();
    this.stopLiveRefresh();
    this.clearEventRefreshTimer();
  }

  async loadData() {
    if (this.isLoadingData) {
      return;
    }

    this.isLoadingData = true;
    try {
      const result = await getExecutionHistoryLive({ limitor: 5000 });
      this.executions = Array.isArray(result) ? result : [];
      this.syncSelectedExecutionIds();
      this.computeKpis();
      this.buildFilterOptions();
      this.applyFilters();
    } catch (e) {
      this.showToast(
        'Error',
        e?.body?.message || e?.message || LBL_TOAST_ERROR_LOADING,
        'error'
      );
    } finally {
      this.isLoadingData = false;
    }
  }

  registerEmpErrorListener() {
    onError((error) => {
      // eslint-disable-next-line no-console
      console.error('EMP API error:', error);
    });
  }

  handleSubscribe() {
    if (this.subscription) {
      return;
    }

    subscribe(this.channelName, -1, (response) => {
      this.handlePlatformEvent(response);
    })
      .then((response) => {
        this.subscription = response;
      })
      .catch((error) => {
        // eslint-disable-next-line no-console
        console.error('Subscription error:', error);
      });
  }

  handleUnsubscribe() {
    if (this.subscription) {
      unsubscribe(this.subscription, () => {});
      this.subscription = null;
    }
  }

  handlePlatformEvent(response) {
    const payload = response?.data?.payload || {};
    const executionId = payload.ExecutionId__c;
    const eventStatus = (payload.Status__c || '').toLowerCase();

    const knownExecutionIds = new Set(
      this.buildExecutionRows()
        .map((row) => row.executionId)
        .filter(Boolean)
    );

    const isKnownExecution = executionId ? knownExecutionIds.has(executionId) : false;
    const shouldWakeUpFromUnknownEvent =
      !this.hasInProgressExecution && (eventStatus === 'inprogress' || eventStatus === 'pending');

    if (!isKnownExecution && !shouldWakeUpFromUnknownEvent) {
      return;
    }

    this.queueRefreshFromEvent();
  }

  queueRefreshFromEvent() {
    this.clearEventRefreshTimer();
    this.eventRefreshTimer = window.setTimeout(() => {
      this.eventRefreshTimer = null;
      this.loadData();
    }, EVENT_REFRESH_DEBOUNCE_MS);
  }

  clearEventRefreshTimer() {
    if (this.eventRefreshTimer) {
      window.clearTimeout(this.eventRefreshTimer);
      this.eventRefreshTimer = null;
    }
  }

  startLiveRefresh() {
    this.stopLiveRefresh();
    this.liveRefreshTimer = window.setInterval(() => {
      if (this.hasInProgressExecution) {
        this.loadData();
      }
    }, POLLING_FALLBACK_INTERVAL_MS);
  }

  stopLiveRefresh() {
    if (this.liveRefreshTimer) {
      window.clearInterval(this.liveRefreshTimer);
      this.liveRefreshTimer = null;
    }
  }

  get hasInProgressExecution() {
    return this.buildExecutionRows().some((row) => this.isInProgressStatus(row.status));
  }

  computeKpis() {
    let totalExec = 0;
    let totalDurationMs = 0;
    let durationCount = 0;
    let totalProcessed = 0;
    let totalFailed = 0;
    const rows = this.buildExecutionRows();

    rows.forEach((row) => {
      totalExec += 1;
      totalProcessed += row.processed;
      totalFailed += row.failed;

      if (row.durationMs > 0) {
        totalDurationMs += row.durationMs;
        durationCount += 1;
      }
    });

    this.totalExecutions = totalExec;
    this.recordsProcessedDisplay = this.formatNumber(totalProcessed);

    const totalSuccess = Math.max(0, totalProcessed - totalFailed);
    const successRate = totalProcessed > 0 ? (totalSuccess / totalProcessed) * 100 : 0;
    this.successRateDisplay = `${successRate.toFixed(1)}%`;

    if (durationCount > 0 && totalDurationMs > 0) {
      const avgMs = totalDurationMs / durationCount;
      this.avgDurationDisplay = this.formatDuration(avgMs);
    } else {
      this.avgDurationDisplay = '0m';
    }
  }

  buildExecutionRows() {
    const rows = [];
    (this.executions || []).forEach((execution) => {
      const total = Number(execution.TotalRecords__c || 0);
      const processed = Number(execution.ProcessedRecords__c || 0);
      const failed = Number(execution.FailedRecords__c || 0);
      const success = Math.max(0, processed - failed);
      const remaining = Math.max(0, total - processed);
      const status = this.normalizeStatus(execution.Status__c);

      const startTime = execution.StartTime__c ? new Date(execution.StartTime__c) : null;
      const endTime = execution.EndTime__c ? new Date(execution.EndTime__c) : null;
      let durationMs = 0;
      if (startTime) {
        const end = endTime && !isNaN(endTime.getTime()) ? endTime : new Date();
        const diff = end.getTime() - startTime.getTime();
        durationMs = diff > 0 ? diff : 0;
      }

      rows.push({
        id: execution.Id,
        executionId: execution.Id,
        projectName: execution?.Project__r?.Name || '',
        targetObject: execution?.Project__r?.TargetObject__c || '-',
        status,
        rawStatus: execution.Status__c,
        type: execution.Type__c || '',
        phase: execution.Phase__c || null,
        total,
        processed,
        failed,
        success,
        remaining,
        durationMs,
        startedAt: execution.StartTime__c || execution.CreatedDate || null,
        executionLabel: `${LBL_EXECUTION_LABEL}${execution.Name || execution.Id}`
      });
    });

    return rows;
  }

  normalizeStatus(status) {
    if (!status) return 'Draft';
    if (status === 'InProgress') return 'Running';
    return status;
  }

  isInProgressStatus(status) {
    return (status || '').toLowerCase() === 'running';
  }

  buildFilterOptions() {
    const projectSet = new Set();
    const targetSet = new Set();

    this.buildExecutionRows().forEach((row) => {
      if (row.projectName) projectSet.add(row.projectName);
      if (row.targetObject) targetSet.add(row.targetObject);
    });

    this.projectOptions = [
      { label: LBL_ALL_PROJECTS, value: 'all' },
      ...Array.from(projectSet).map((name) => ({ label: name, value: name }))
    ];

    this.targetOptions = [
      { label: LBL_ALL_OBJECTS, value: 'all' },
      ...Array.from(targetSet).map((obj) => ({ label: obj, value: obj }))
    ];
  }

  handleStatusChange(event) {
    this.statusFilter = event.target.value ?? event.detail?.value ?? 'all';
  }

  handleDateRangeChange(event) {
    this.dateRangeFilter = event.target.value ?? event.detail?.value ?? 'all';
  }

  handleProjectChange(event) {
    this.projectFilter = event.target.value ?? event.detail?.value ?? 'all';
  }

  handleTargetChange(event) {
    this.targetFilter = event.target.value ?? event.detail?.value ?? 'all';
  }

  get statusOptionsWithSelected() {
    return this.statusOptions.map(o => ({ ...o, isSelected: o.value === this.statusFilter }));
  }
  get dateRangeOptionsWithSelected() {
    return this.dateRangeOptions.map(o => ({ ...o, isSelected: o.value === this.dateRangeFilter }));
  }
  get projectOptionsWithSelected() {
    return this.projectOptions.map(o => ({ ...o, isSelected: o.value === this.projectFilter }));
  }

  handleApplyFilters() {
    this.applyFilters();
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value || '';
    this.applyFilters();
  }

  applyFilters() {
    const now = new Date();
    let cutoffDate = null;

    if (this.dateRangeFilter !== 'all') {
      const days = parseInt(this.dateRangeFilter, 10);
      cutoffDate = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
    }

    const search = (this.searchTerm || '').toLowerCase();
    const rows = this.buildExecutionRows().filter((row) => {
      const startedDate = row.startedAt ? new Date(row.startedAt) : null;

      if (cutoffDate && startedDate && startedDate < cutoffDate) {
        return false;
      }

      if (this.statusFilter !== 'all' && row.status !== this.statusFilter) {
        return false;
      }

      if (this.projectFilter !== 'all' && row.projectName !== this.projectFilter) {
        return false;
      }

      if (this.targetFilter !== 'all' && row.targetObject !== this.targetFilter) {
        return false;
      }

      const textToSearch = (
        row.projectName +
        ' ' +
        row.targetObject +
        ' ' +
        row.status +
        ' ' +
        (row.phase || '') +
        ' ' +
        row.executionLabel
      ).toLowerCase();

      if (search && !textToSearch.includes(search)) {
        return false;
      }

      return true;
    });

    rows.sort((a, b) => {
      const da = a.startedAt ? new Date(a.startedAt).getTime() : 0;
      const db = b.startedAt ? new Date(b.startedAt).getTime() : 0;
      return db - da;
    });

    this.filteredRows = rows;
    this.currentPage = 1;
    this.updatePageRows();
  }

  updatePageRows() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    const slice = this.filteredRows.slice(start, end);
    const selectedIdSet = new Set(this.selectedExecutionIds);

    this.pageRows = slice.map((r) => {
      const statusLower = (r.status || '').toLowerCase();
      let statusLabel = r.status || LBL_STATUS_DRAFT;
      let actionLabel = LBL_ACTION_VIEW;
      let statusClass = 'ih-status-pill ih-status-draft';
      let showStatusDot = false;
      let statusDotClass = '';

      if (statusLower === 'completed') {
        statusLabel = LBL_STATUS_COMPLETED;
        statusClass = 'ih-status-pill ih-status-success';
      } else if (statusLower === 'running') {
        statusLabel = LBL_STATUS_RUNNING;
        statusClass = 'ih-status-pill ih-status-running';
        actionLabel = LBL_ACTION_MONITOR;
        showStatusDot = true;
        statusDotClass = 'ih-status-dot ih-status-dot-running';
      } else if (statusLower === 'failed') {
        statusLabel = LBL_STATUS_FAILED;
        statusClass = 'ih-status-pill ih-status-failed';
        actionLabel = LBL_ACTION_DEBUG;
        showStatusDot = true;
        statusDotClass = 'ih-status-dot ih-status-dot-failed';
      } else if (statusLower === 'cancelled') {
        statusLabel = LBL_STATUS_CANCELLED;
        statusClass = 'ih-status-pill ih-status-failed';
        actionLabel = LBL_ACTION_DEBUG;
        showStatusDot = true;
        statusDotClass = 'ih-status-dot ih-status-dot-failed';
      } else if (statusLower === 'draft') {
        statusLabel = LBL_STATUS_DRAFT;
      }

      const recordsText = this.buildRecordsText(
        r.processed,
        r.total,
        r.failed,
        r.remaining
      );

      const phaseText = r.phase
        ? `${LBL_PHASE_PREFIX}${r.phase}`
        : LBL_PHASE_NA;

      const nameLower = (r.projectName || '').toLowerCase();
      const targetLower = (r.targetObject || '').toLowerCase();

      let iconName = 'standard:record';
      let iconEmoji = '📋';
      let iconBgClass = 'ih-project-icon ih-project-icon-generic';

      if (targetLower.includes('contact')) {
        iconName = 'standard:contact'; iconEmoji = '👤';
        iconBgClass = 'ih-project-icon ih-project-icon-blue';
      } else if (targetLower.includes('opportunity')) {
        iconName = 'standard:opportunity'; iconEmoji = '💰';
        iconBgClass = 'ih-project-icon ih-project-icon-orange';
      } else if (targetLower.includes('account')) {
        iconName = 'standard:account'; iconEmoji = '🏢';
        iconBgClass = 'ih-project-icon ih-project-icon-purple';
      } else if (targetLower.includes('lead')) {
        iconName = 'standard:lead'; iconEmoji = '⚡';
        iconBgClass = 'ih-project-icon ih-project-icon-indigo';
      }

      if (nameLower.includes('analytics') || nameLower.includes('report')) {
        iconName = 'standard:dashboard'; iconEmoji = '📈';
        iconBgClass = 'ih-project-icon ih-project-icon-pink';
      } else if (nameLower.includes('migration') || nameLower.includes('sync')) {
        iconName = 'standard:flow'; iconEmoji = '🔄';
        iconBgClass = 'ih-project-icon ih-project-icon-teal';
      }

      return {
        ...r,
        isSelected: selectedIdSet.has(r.id),
        statusLabel,
        statusClass,
        actionLabel,
        canDelete: statusLower !== 'running',
        recordsText,
        phaseText,
        durationText: this.formatDuration(r.durationMs),
        startedText: this.formatRelativeTime(r.startedAt),
        iconName,
        iconEmoji,
        iconBgClass,
        showStatusDot,
        statusDotClass
      };
    });
  }

  get totalRows() {
    return this.filteredRows.length;
  }

  get totalPages() {
    return this.totalRows ? Math.ceil(this.totalRows / this.pageSize) : 1;
  }

  get firstRowIndex() {
    if (!this.totalRows) return 0;
    return (this.currentPage - 1) * this.pageSize + 1;
  }

  get lastRowIndex() {
    return Math.min(this.currentPage * this.pageSize, this.totalRows);
  }

  get showingText() {
    return LBL_TABLE_SHOWING
      .replace('{0}', this.firstRowIndex)
      .replace('{1}', this.lastRowIndex)
      .replace('{2}', this.totalRows);
  }

  get isPreviousDisabled() {
    return this.currentPage <= 1;
  }

  get isNextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  get isDeleteSelectedDisabled() {
    const status = (this.selectedRow?.status || '').toLowerCase();
    return this.isBusy || status === 'running';
  }

  get selectedCount() {
    return this.selectedExecutionIds.length;
  }

  get deleteSelectedLabel() {
    return LBL_ACTION_DELETE_SELECTED.replace('{0}', this.selectedCount);
  }

  get isBulkDeleteDisabled() {
    return this.isBusy || this.selectedCount === 0;
  }

  get isAllPageSelected() {
    if (!this.pageRows.length) {
      return false;
    }

    const selectedIdSet = new Set(this.selectedExecutionIds);
    return this.pageRows.every((row) => selectedIdSet.has(row.id));
  }

  get isBusy() {
    return this.isLoadingData || this.isDeleting;
  }

  handlePrevious() {
    if (this.currentPage > 1) {
      this.currentPage -= 1;
      this.updatePageRows();
    }
  }

  handleNext() {
    if (this.currentPage < this.totalPages) {
      this.currentPage += 1;
      this.updatePageRows();
    }
  }

  handleRowClick(event) {
    const id = event.currentTarget.dataset.id;
    if (!id) return;
    const row = (this.pageRows || []).find((r) => r.id === id);
    if (!row) return;
    this.selectedRow = { ...row };
    this.showViewModal = true;
  }

  // Prevent row-level click from firing when interacting with cells that
  // contain checkboxes or action buttons.
  handleCellClick(event) {
    event.stopPropagation();
  }

  handleView(event) {
    event.stopPropagation();
    const id = event.currentTarget.dataset.id;
    const row = (this.pageRows || []).find((r) => r.id === id);

    if (!row) {
      this.showToast('Error', LBL_TOAST_ERR_LOAD_DETAILS, 'error');
      return;
    }

    this.selectedRow = { ...row };
    this.showViewModal = true;
  }

  handleToggleSelectRow(event) {
    const executionId = event.currentTarget?.dataset?.id;
    if (!executionId) {
      return;
    }

    const selectedIdSet = new Set(this.selectedExecutionIds);
    if (event.target.checked) {
      selectedIdSet.add(executionId);
    } else {
      selectedIdSet.delete(executionId);
    }

    this.selectedExecutionIds = [...selectedIdSet];
    this.updatePageRows();
  }

  handleToggleSelectPage(event) {
    const selectedIdSet = new Set(this.selectedExecutionIds);
    const shouldSelectAll = !!event.target.checked;

    this.pageRows.forEach((row) => {
      if (shouldSelectAll) {
        selectedIdSet.add(row.id);
      } else {
        selectedIdSet.delete(row.id);
      }
    });

    this.selectedExecutionIds = [...selectedIdSet];
    this.updatePageRows();
  }

  async handleDeleteSelected() {
    const executionIds = [...this.selectedExecutionIds];
    if (!executionIds.length) {
      this.showToast('Info', LBL_TOAST_SELECT_ONE, 'info');
      return;
    }

    const confirmed = window.confirm(
      LBL_CONFIRM_DELETE_MULTI.replace('{0}', executionIds.length)
    );
    if (!confirmed) {
      return;
    }

    try {
      this.isDeleting = true;
      const result = await deleteExecutionHistories({ executionIds });
      const deletedCount = Number(result?.deletedCount || 0);
      const skippedRunningCount = Number(result?.skippedRunningCount || 0);
      const skippedNotFoundCount = Number(result?.skippedNotFoundCount || 0);
      const skippedStagingCount = Number(result?.skippedStagingCount || 0);
      const failedCount = Number(result?.failedCount || 0);

      let message = `${deletedCount} deleted`;
      if (skippedRunningCount > 0) message += `, ${skippedRunningCount} running`;
      if (skippedNotFoundCount > 0) message += `, ${skippedNotFoundCount} not found`;
      if (skippedStagingCount > 0) message += `, ${skippedStagingCount} staging blocked`;
      if (failedCount > 0) message += `, ${failedCount} failed`;

      if (deletedCount > 0) {
        this.showToast('Success', message, 'success');
      } else {
        this.showToast('Warning', message, 'warning');
      }

      if (this.selectedRow?.id && executionIds.includes(this.selectedRow.id) && deletedCount > 0) {
        this.closeViewModal();
      }

      this.selectedExecutionIds = [];
      await this.loadData();
    } catch (e) {
      this.showToast(
        'Error',
        e?.body?.message || e?.message || LBL_TOAST_ERR_DEL_SELECTED,
        'error'
      );
    } finally {
      this.isDeleting = false;
    }
  }

  async handleDeleteExecution(event) {
    event.stopPropagation();
    const executionId = event.currentTarget?.dataset?.id;
    if (!executionId) {
      this.showToast('Error', LBL_TOAST_EXEC_ID_MISSING, 'error');
      return;
    }

    const row = (this.filteredRows || []).find((r) => r.id === executionId);
    const status = (row?.status || '').toLowerCase();
    if (status === 'running') {
      this.showToast('Warning', LBL_TOAST_CANNOT_DEL_RUN, 'warning');
      return;
    }

    const confirmed = window.confirm(LBL_CONFIRM_DELETE_SINGLE);
    if (!confirmed) {
      return;
    }

    try {
      this.isDeleting = true;
      await deleteExecutionHistory({ executionId });
      this.selectedExecutionIds = this.selectedExecutionIds.filter((id) => id !== executionId);

      if (this.selectedRow?.id === executionId) {
        this.closeViewModal();
      }

      this.showToast('Success', LBL_TOAST_DELETE_SUCCESS, 'success');
      await this.loadData();
    } catch (e) {
      this.showToast(
        'Error',
        e?.body?.message || e?.message || LBL_TOAST_ERR_DEL_SINGLE,
        'error'
      );
    } finally {
      this.isDeleting = false;
    }
  }

  handleNewImportProject() {
    this.showCreateModal = true;
  }

  handleCreateCancel() {
    this.showCreateModal = false;
  }

  handleProjectSaved(event) {
    const proj = event.detail;
    this.showCreateModal = false;

    this.showToast(
      LBL_TOAST_PROJECT_CREATED,
      LBL_TOAST_PROJECT_CREATED_MSG.replace('{0}', proj?.Name || proj?.Id || ''),
      'success'
    );

    this.loadData();
  }

  handleExport() {
    if (!this.filteredRows.length) {
      this.showToast('Info', LBL_TOAST_NOTHING_EXPORT, 'info');
      return;
    }

    const header = [
      'Project', 'Target Object', 'Status',
      'Processed', 'Total', 'Failed', 'Started', 'Duration'
    ];

    const rows = this.filteredRows.map((r) => [
      `"${r.projectName || ''}"`,
      `"${r.targetObject || ''}"`,
      `"${r.status || ''}"`,
      r.processed || 0,
      r.total || 0,
      r.failed || 0,
      `"${r.startedAt || ''}"`,
      `"${this.formatDuration(r.durationMs)}"`
    ]);

    const csv = [header.join(','), ...rows.map((x) => x.join(','))].join('\n');
    this.downloadCsv(csv, 'import-history.csv');
  }

  handleExportSelected() {
    if (!this.selectedRow) {
      this.showToast('Info', LBL_TOAST_NO_EXEC_SELECTED, 'info');
      return;
    }

    const r = this.selectedRow;
    const header = [
      'Project', 'Target Object', 'Status',
      'Processed', 'Total', 'Failed', 'Started', 'Duration'
    ];

    const row = [
      `"${r.projectName || ''}"`,
      `"${r.targetObject || ''}"`,
      `"${r.status || ''}"`,
      r.processed || 0,
      r.total || 0,
      r.failed || 0,
      `"${r.startedAt || ''}"`,
      `"${r.durationText || this.formatDuration(r.durationMs)}"`
    ];

    const csv = [header.join(','), row.join(',')].join('\n');
    const safeName = (r.projectName || 'execution').replace(/[^a-zA-Z0-9-_]/g, '_');
    this.downloadCsv(csv, `import-execution-${safeName}.csv`);
  }

  downloadCsv(csv, fileName) {
    try {
      const csvContent = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
      const link = document.createElement('a');
      link.href = csvContent;
      link.download = fileName || 'export.csv';
      link.target = '_self';
      link.style.display = 'none';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (e) {
      this.showToast('Error', e?.message || LBL_TOAST_ERR_EXPORT_CSV, 'error');
    }
  }

  closeViewModal() {
    this.showViewModal = false;
    this.selectedRow = null;
  }

  syncSelectedExecutionIds() {
    if (!this.selectedExecutionIds.length) {
      return;
    }

    const validExecutionIds = new Set((this.executions || []).map((execution) => execution.Id));
    this.selectedExecutionIds = this.selectedExecutionIds.filter((executionId) =>
      validExecutionIds.has(executionId)
    );
  }

  buildRecordsText(processed, total, failed, remaining) {
    const t = total || 0;
    const p = processed || 0;
    const f = failed || 0;
    const r = remaining || 0;

    if (t === 0 && p === 0 && f > 0) {
      return `${f} errors`;
    }

    if (t > 0) {
      if (f > 0) {
        return `${p} / ${t} (${f} failed)`;
      }
      if (r > 0) {
        return `${p} / ${t} (${r} remaining)`;
      }
      return `${p} / ${t}`;
    }

    return `${p}`;
  }

  formatDuration(ms) {
    if (!ms || ms <= 0) {
      return '-';
    }

    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;

    if (hours > 0) {
      return `${hours}h ${mins}m`;
    }
    if (mins > 0) {
      return `${mins}m ${seconds}s`;
    }
    return `${seconds}s`;
  }

  formatRelativeTime(dateString) {
    if (!dateString) return '-';
    const date = new Date(dateString);
    if (isNaN(date.getTime())) return '-';
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffSec = Math.floor(diffMs / 1000);
    const diffMin = Math.floor(diffSec / 60);
    const diffHour = Math.floor(diffMin / 60);
    const diffDay = Math.floor(diffHour / 24);

    if (diffDay >= 2) return LBL_TIME_X_DAYS_AGO.replace('{0}', diffDay);
    if (diffDay === 1) return LBL_TIME_1DAY_AGO;
    if (diffHour >= 2) return LBL_TIME_X_HOURS_AGO.replace('{0}', diffHour);
    if (diffHour === 1) return LBL_TIME_1HOUR_AGO;
    if (diffMin >= 2) return LBL_TIME_X_MIN_AGO.replace('{0}', diffMin);
    if (diffMin === 1) return LBL_TIME_1MIN_AGO;
    return LBL_TIME_JUST_NOW;
  }

  formatNumber(num) {
    const n = num || 0;
    if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
    if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
    return n.toString();
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({ title, message, variant })
    );
  }
}