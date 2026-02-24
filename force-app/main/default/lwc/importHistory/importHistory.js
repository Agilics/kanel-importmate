import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExecutionHistoryLive from '@salesforce/apex/DashboardController.getExecutionHistoryLive';
import deleteExecutionHistory from '@salesforce/apex/DashboardController.deleteExecutionHistory';
import deleteExecutionHistories from '@salesforce/apex/DashboardController.deleteExecutionHistories';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

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

 
  statusFilter = 'all';
  dateRangeFilter = 'all';
  projectFilter = 'all';
  targetFilter = 'all';
  searchTerm = '';
  statusOptions = [
    { label: 'All Statuses', value: 'all' },
    { label: 'Completed', value: 'Completed' },
    { label: 'Running', value: 'Running' },
    { label: 'Failed', value: 'Failed' },
    { label: 'Cancelled', value: 'Cancelled' },
    { label: 'Draft', value: 'Draft' }
  ];

  dateRangeOptions = [
    { label: 'Last 7 days', value: '7' },
    { label: 'Last 30 days', value: '30' },
    { label: 'Last 90 days', value: '90' },
    { label: 'All time', value: 'all' }
  ];

  projectOptions = [{ label: 'All Projects', value: 'all' }];
  targetOptions = [{ label: 'All Objects', value: 'all' }];


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
        e?.body?.message || e?.message || 'Error loading import history',
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
        executionLabel: `Execution #${execution.Name || execution.Id}`
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
      { label: 'All Projects', value: 'all' },
      ...Array.from(projectSet).map((name) => ({ label: name, value: name }))
    ];

    this.targetOptions = [
      { label: 'All Objects', value: 'all' },
      ...Array.from(targetSet).map((obj) => ({ label: obj, value: obj }))
    ];
  }

  handleStatusChange(event) {
    this.statusFilter = event.detail.value;
  }

  handleDateRangeChange(event) {
    this.dateRangeFilter = event.detail.value;
  }

  handleProjectChange(event) {
    this.projectFilter = event.detail.value;
  }

  handleTargetChange(event) {
    this.targetFilter = event.detail.value;
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
      let statusLabel = r.status || 'Draft';
      let actionLabel = 'View';
      let statusClass = 'ih-status-pill ih-status-draft';
      let showStatusDot = false;
      let statusDotClass = '';

      if (statusLower === 'completed') {
        statusClass = 'ih-status-pill ih-status-success';
      } else if (statusLower === 'running') {
        statusClass = 'ih-status-pill ih-status-running';
        actionLabel = 'Monitor';
        showStatusDot = true;
        statusDotClass = 'ih-status-dot ih-status-dot-running';
      } else if (statusLower === 'failed' || statusLower === 'cancelled') {
        statusClass = 'ih-status-pill ih-status-failed';
        actionLabel = 'Debug';
        showStatusDot = true;
        statusDotClass = 'ih-status-dot ih-status-dot-failed';
      }

      const recordsText = this.buildRecordsText(
        r.processed,
        r.total,
        r.failed,
        r.remaining
      );

      const phaseText = r.phase ? `Phase: ${r.phase}` : 'Phase: N/A';

      const nameLower = (r.projectName || '').toLowerCase();
      const targetLower = (r.targetObject || '').toLowerCase();

      let iconName = 'standard:record';
      let iconBgClass = 'ih-project-icon ih-project-icon-generic';

      if (targetLower.includes('contact')) {
        iconName = 'standard:contact';
        iconBgClass = 'ih-project-icon ih-project-icon-blue';
      } else if (targetLower.includes('opportunity')) {
        iconName = 'standard:opportunity';
        iconBgClass = 'ih-project-icon ih-project-icon-orange';
      } else if (targetLower.includes('account')) {
        iconName = 'standard:account';
        iconBgClass = 'ih-project-icon ih-project-icon-purple';
      } else if (targetLower.includes('lead')) {
        iconName = 'standard:lead';
        iconBgClass = 'ih-project-icon ih-project-icon-indigo';
      }

      if (nameLower.includes('analytics') || nameLower.includes('report')) {
        iconName = 'standard:dashboard';
        iconBgClass = 'ih-project-icon ih-project-icon-pink';
      } else if (nameLower.includes('migration') || nameLower.includes('sync')) {
        iconName = 'standard:flow';
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
    return `Delete Selected (${this.selectedCount})`;
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

  handleView(event) {
    const id = event.currentTarget.dataset.id;
    const row = (this.pageRows || []).find((r) => r.id === id);

    if (!row) {
      this.showToast('Error', 'Unable to load execution details.', 'error');
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
      this.showToast('Info', 'Select at least one execution.', 'info');
      return;
    }

    const confirmed = window.confirm(
      `Delete ${executionIds.length} execution history item(s) and related logs?`
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
      if (skippedRunningCount > 0) {
        message += `, ${skippedRunningCount} running`;
      }
      if (skippedNotFoundCount > 0) {
        message += `, ${skippedNotFoundCount} not found`;
      }
      if (skippedStagingCount > 0) {
        message += `, ${skippedStagingCount} staging blocked`;
      }
      if (failedCount > 0) {
        message += `, ${failedCount} failed`;
      }

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
        e?.body?.message || e?.message || 'Unable to delete selected executions.',
        'error'
      );
    } finally {
      this.isDeleting = false;
    }
  }

  async handleDeleteExecution(event) {
    const executionId = event.currentTarget?.dataset?.id;
    if (!executionId) {
      this.showToast('Error', 'Execution ID is missing.', 'error');
      return;
    }

    const row = (this.filteredRows || []).find((r) => r.id === executionId);
    const status = (row?.status || '').toLowerCase();
    if (status === 'running') {
      this.showToast('Warning', 'Cannot delete an execution that is running.', 'warning');
      return;
    }

    const confirmed = window.confirm('Delete this execution history and related logs?');
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

      this.showToast('Success', 'Execution history deleted.', 'success');
      await this.loadData();
    } catch (e) {
      this.showToast(
        'Error',
        e?.body?.message || e?.message || 'Unable to delete execution history.',
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
      'Project created',
      `Project ${proj?.Name || proj?.Id || ''} created successfully`,
      'success'
    );

    this.loadData();
  }

  handleExport() {
    if (!this.filteredRows.length) {
      this.showToast('Info', 'Nothing to export.', 'info');
      return;
    }

    const header = [
      'Project',
      'Target Object',
      'Status',
      'Processed',
      'Total',
      'Failed',
      'Started',
      'Duration'
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
      this.showToast('Info', 'No execution selected to export.', 'info');
      return;
    }

    const r = this.selectedRow;

    const header = [
      'Project',
      'Target Object',
      'Status',
      'Processed',
      'Total',
      'Failed',
      'Started',
      'Duration'
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
      this.showToast(
        'Error',
        e?.message || 'Unable to export CSV.',
        'error'
      );
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

    if (diffDay >= 2) return `${diffDay} days ago`;
    if (diffDay === 1) return `1 day ago`;
    if (diffHour >= 2) return `${diffHour} hours ago`;
    if (diffHour === 1) return `1 hour ago`;
    if (diffMin >= 2) return `${diffMin} minutes ago`;
    if (diffMin === 1) return `1 minute ago`;
    return `Just now`;
}


  formatNumber(num) {
    const n = num || 0;
    if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
    if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
    return n.toString();
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}
