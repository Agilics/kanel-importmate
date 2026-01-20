import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDashboardData from '@salesforce/apex/DashboardController.getDashboardData';

const PAGE_SIZE = 10;

export default class ImportHistory extends LightningElement {
  @track projects = [];
  @track filteredRows = [];
  @track pageRows = [];

  @track showCreateModal = false;
  @track showViewModal = false;
  @track selectedRow = null;

 
  statusFilter = 'all';
  dateRangeFilter = '30'; 
  projectFilter = 'all';
  targetFilter = 'all';
  searchTerm = '';
  statusOptions = [
    { label: 'All Statuses', value: 'all' },
    { label: 'Completed', value: 'Completed' },
    { label: 'Running', value: 'Running' },
    { label: 'Failed', value: 'Failed' },
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

  connectedCallback() {
    this.loadData();
  }

  async loadData() {
    try {
      const result = await getDashboardData({ limitor: 200 });
      const projects = Array.isArray(result?.projects) ? result.projects : [];
      this.projects = projects;

      this.computeKpis(result);
      this.buildFilterOptions();
      this.applyFilters();
    } catch (e) {
      this.showToast(
        'Error',
        e?.body?.message || e?.message || 'Error loading import history',
        'error'
      );
    }
  }

  computeKpis(result) {
    let totalExec = 0;
    let totalDurationMs = 0;
    let totalProcessed = 0;
    let successRateFormatted = result?.stats?.successRateFormatted;
    let recordsImportedFormatted = result?.stats?.recordsImportedFormatted;

    this.projects.forEach((p) => {
      const execs = p.ImportExecutions__r || [];
      execs.forEach((ex) => {
        totalExec += 1;

        const total = ex.TotalRecords__c || 0;
        const processed = ex.ProcessedRecords__c || 0;
        totalProcessed += processed || total;

        if (ex.StartTime__c && ex.EndTime__c) {
          const start = new Date(ex.StartTime__c);
          const end = new Date(ex.EndTime__c);
          const diff = end.getTime() - start.getTime();
          if (!isNaN(diff) && diff > 0) totalDurationMs += diff;
        }
      });
    });

    this.totalExecutions = totalExec;

    if (successRateFormatted) {
      this.successRateDisplay = successRateFormatted;
    } else {
      this.successRateDisplay = totalExec > 0 ? '100%' : '0%';
    }

    if (recordsImportedFormatted) {
      this.recordsProcessedDisplay = recordsImportedFormatted;
    } else {
      this.recordsProcessedDisplay = this.formatNumber(totalProcessed);
    }

    if (totalExec > 0 && totalDurationMs > 0) {
      const avgMs = totalDurationMs / totalExec;
      this.avgDurationDisplay = this.formatDuration(avgMs);
    } else {
      this.avgDurationDisplay = '0m';
    }
  }


  buildFilterOptions() {
    const projectSet = new Set();
    const targetSet = new Set();

    this.projects.forEach((p) => {
      if (p.Name) projectSet.add(p.Name);
      if (p.TargetObject__c) targetSet.add(p.TargetObject__c);
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
    const rows = [];

    this.projects.forEach((p) => {
      const execs = p.ImportExecutions__r || [];
      const ex = execs.length ? execs[0] : null;

      const startedAt = ex?.StartTime__c || p.CreatedDate;
      const startedDate = startedAt ? new Date(startedAt) : null;

      if (cutoffDate && startedDate && startedDate < cutoffDate) {
        return;
      }

      const status = ex?.Status__c || 'Draft';
      const target = p.TargetObject__c || '';
      const name = p.Name || '';

      if (this.statusFilter !== 'all' && status !== this.statusFilter) {
        return;
      }

      if (this.projectFilter !== 'all' && name !== this.projectFilter) {
        return;
      }

      if (this.targetFilter !== 'all' && target !== this.targetFilter) {
        return;
      }

      const total = ex?.TotalRecords__c || 0;
      const processed = ex?.ProcessedRecords__c || 0;
      const failed = ex?.FailedRecords__c || 0;

      const startTime = ex?.StartTime__c ? new Date(ex.StartTime__c) : null;
      const endTime = ex?.EndTime__c ? new Date(ex.EndTime__c) : null;
      let durationMs = 0;
      if (startTime && endTime) {
        durationMs = endTime.getTime() - startTime.getTime();
      }

      const executionLabel = ex
        ? `Execution #${ex.Name || ex.Id}`
        : 'No execution yet';

      const textToSearch =
        (name + ' ' + target + ' ' + status + ' ' + executionLabel).toLowerCase();

      if (search && !textToSearch.includes(search)) {
        return;
      }

      rows.push({
        id: ex?.Id || p.Id,
        projectName: name,
        targetObject: target || '—',
        status,
        total,
        processed,
        failed,
        durationMs,
        startedAt,
        executionLabel
      });
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
    } else if (statusLower === 'failed') {
      statusClass = 'ih-status-pill ih-status-failed';
      actionLabel = 'Debug';
      showStatusDot = true;
      statusDotClass = 'ih-status-dot ih-status-dot-failed';
    }

    const recordsText = this.buildRecordsText(
      r.processed,
      r.total,
      r.failed
    );

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
      statusLabel,
      statusClass,
      actionLabel,
      recordsText,
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

    if (proj && proj.Id) {
      const newProj = {
        ...proj,
        ImportExecutions__r: proj.ImportExecutions__r || []
      };

      if (!newProj.CreatedDate) {
        newProj.CreatedDate = new Date().toISOString();
      }

      this.projects = [newProj, ...this.projects];

      this.buildFilterOptions();
      this.applyFilters();
    } else {
      this.loadData();
    }
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

  buildRecordsText(processed, total, failed) {
    const t = total || 0;
    const p = processed || 0;
    const f = failed || 0;

    if (t === 0 && p === 0 && f > 0) {
      return `${f} errors`;
    }

    if (t > 0) {
      return `${p} / ${t}`;
    }

    return `${p}`;
  }

  formatDuration(ms) {
    if (!ms || ms <= 0) {
      return '—';
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
    if (!dateString) return '—';
    const date = new Date(dateString);
    if (isNaN(date.getTime())) return '—';

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