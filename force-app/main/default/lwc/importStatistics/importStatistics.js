import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExecutionHistoryLive from '@salesforce/apex/DashboardController.getExecutionHistoryLive';

// --- Labels ---
// To enable Custom Labels once deployed, replace this block with:
//   import LBL_TITLE from '@salesforce/label/c.IS_Title'; etc.
// and substitute LABELS.xxx with the imported variables.
const LABELS = {
  title:           'Import Statistics',
  subtitle:        'Performance metrics and charts for your import executions',
  refresh:         'Refresh',
  export:          'Export',
  kpiTotal:        'Total Executions',
  kpiSuccessRate:  'Success Rate',
  kpiRecords:      'Records Processed',
  kpiAvgDuration:  'Avg. Duration',
  kpiFailed:       'Failed / Cancelled',
  kpiRunning:      'Currently Running',
  chartStatus:     'Status Distribution',
  chartVolume:     'Execution Volume by Day',
  chartDuration:   'Avg. Duration by Project',
  chartSuccess:    'Success Rate Over Time',
  chartTopProjects:'Top Projects',
  chartObjects:    'Records by Target Object',
  period7:         'Last 7 days',
  period30:        'Last 30 days',
  period90:        'Last 90 days',
  periodAll:       'All time',
  noData:          'No data available for this period.',
  loading:         'Loading statistics...',
  errorLoading:    'Error loading statistics',
  legendCompleted: 'Completed',
  legendRunning:   'Running',
  legendFailed:    'Failed',
  legendCancelled: 'Cancelled',
  legendDraft:     'Draft',
  tableProject:    'Project',
  tableExecutions: 'Executions',
  tableRecords:    'Records',
  tableSuccess:    'Success Rate',
  tableAvgDur:     'Avg. Duration'
};
// ---

const STATUS_COLORS = {
  Completed: '#10b981',
  Running:   '#3b82f6',
  Failed:    '#ef4444',
  Cancelled: '#f59e0b',
  Draft:     '#94a3b8'
};

const CHART_PALETTE = ['#3b82f6', '#10b981', '#8b5cf6', '#06b6d4', '#f59e0b', '#ec4899', '#14b8a6'];

export default class ImportStatistics extends LightningElement {

  label = { ...LABELS };

  @track isLoading = false;
  @track executions = [];
  @track selectedPeriod = '30';
  @track activeTab = 'overview';

  @track kpis = {
    total: 0,
    successRate: '0%',
    totalRecords: '0',
    avgDuration: '-',
    failed: 0,
    running: 0,
    trend: 0,
    trendLabel: ''
  };

  @track statusDonutSlices = [];
  @track statusLegend = [];
  @track volumeBars = [];
  @track durationBars = [];
  @track successTrendPoints = [];
  @track topProjects = [];
  @track objectBars = [];
  @track projectExecBars = [];

  // -- Trend summary stats --
  _trendRates = [];

  // -- Getters --
  get periodOptions() {
    return [
      { label: LABELS.period7,   value: '7' },
      { label: LABELS.period30,  value: '30' },
      { label: LABELS.period90,  value: '90' },
      { label: LABELS.periodAll, value: 'all' }
    ];
  }

  get periodOptionsWithSelected() {
    return this.periodOptions.map(o => ({ ...o, isSelected: o.value === this.selectedPeriod }));
  }

  get selectedPeriodLabel() {
    const map = { '7': LABELS.period7, '30': LABELS.period30, '90': LABELS.period90, 'all': LABELS.periodAll };
    return map[this.selectedPeriod] || '';
  }

  get tabOverviewActive()  { return this.activeTab === 'overview'; }
  get tabTrendsActive()    { return this.activeTab === 'trends'; }
  get tabProjectsActive()  { return this.activeTab === 'projects'; }

  get tabOverviewClass()  { return 'is-tab' + (this.activeTab === 'overview'  ? ' is-tab-active' : ''); }
  get tabTrendsClass()    { return 'is-tab' + (this.activeTab === 'trends'    ? ' is-tab-active' : ''); }
  get tabProjectsClass()  { return 'is-tab' + (this.activeTab === 'projects'  ? ' is-tab-active' : ''); }

  get successRateNum()   { return parseFloat(this.kpis.successRate) || 0; }

  get successRateColor() {
    const n = this.successRateNum;
    if (n >= 90) return '#10b981';
    if (n >= 70) return '#f59e0b';
    return '#ef4444';
  }

  get gaugeOffset()     { return 157 - (this.successRateNum / 100) * 157; }
  get gaugeValueStyle() { return 'color: ' + this.successRateColor + ';'; }

  get hasVolumeData()   { return this.volumeBars.length > 0; }
  get hasDurationData() { return this.durationBars.length > 0; }
  get hasTrendData()    { return this.successTrendPoints.length > 0; }
  get hasObjectData()   { return this.objectBars.length > 0; }
  get hasTopProjects()  { return this.topProjects.length > 0; }
  get hasComboData()    { return this.successTrendPoints.length > 0; }

  // -- Trend summary getters --
  get trendMin() {
    if (!this._trendRates.length) return '-';
    return Math.min(...this._trendRates).toFixed(1) + '%';
  }

  get trendMax() {
    if (!this._trendRates.length) return '-';
    return Math.max(...this._trendRates).toFixed(1) + '%';
  }

  get trendAvg() {
    if (!this._trendRates.length) return '-';
    const avg = this._trendRates.reduce((s, v) => s + v, 0) / this._trendRates.length;
    return avg.toFixed(1) + '%';
  }

  get trendPointCount() {
    return this._trendRates.length;
  }

  get trendSummaryLabel() {
    if (!this._trendRates.length) return '';
    const avg = this._trendRates.reduce((s, v) => s + v, 0) / this._trendRates.length;
    return 'Moy. ' + avg.toFixed(1) + '%';
  }

  // -- Lifecycle --
  connectedCallback() {
    this.loadData();
  }

  // -- Data --
  async loadData() {
    this.isLoading = true;
    try {
      const result = await getExecutionHistoryLive({ limitor: 5000 });
      this.executions = Array.isArray(result) ? result : [];
      this._compute();
    } catch (e) {
      this._toast('Error', (e && e.body && e.body.message) || LABELS.errorLoading, 'error');
    } finally {
      this.isLoading = false;
    }
  }

  // -- Handlers --
  handlePeriodChange(event) {
    this.selectedPeriod = event.target.value ?? event.detail?.value ?? '';
    this._compute();
  }

  handleTabChange(event) {
    this.activeTab = event.currentTarget.dataset.tab;
  }

  handleRefresh() {
    this.loadData();
  }

  // -- Computation --
  _compute() {
    const rows = this._filterByPeriod(this._normalize(this.executions));
    this._computeKpis(rows);
    this._computeStatusDonut(rows);
    this._computeVolumeBars(rows);
    this._computeDurationBars(rows);
    this._computeSuccessTrend(rows);
    this._computeTopProjects(rows);
    this._computeObjectBars(rows);
  }

  _normalize(execs) {
    return (execs || []).map(e => {
      const processed = Number(e.ProcessedRecords__c || 0);
      const failed    = Number(e.FailedRecords__c    || 0);
      let status = e.Status__c || 'Draft';
      if (status === 'InProgress') status = 'Running';

      const startTime = e.StartTime__c ? new Date(e.StartTime__c) : null;
      const endTime   = e.EndTime__c   ? new Date(e.EndTime__c)   : null;
      let durationMs  = 0;
      if (startTime) {
        const end  = endTime && !isNaN(endTime) ? endTime : new Date();
        const diff = end - startTime;
        durationMs = diff > 0 ? diff : 0;
      }

      return {
        id:        e.Id,
        project:   (e.Project__r && e.Project__r.Name) || 'Unknown',
        targetObj: (e.Project__r && e.Project__r.TargetObject__c) || 'Unknown',
        status,
        total:     Number(e.TotalRecords__c || 0),
        processed,
        failed,
        durationMs,
        startedAt: startTime
      };
    });
  }

  _filterByPeriod(rows) {
    if (this.selectedPeriod === 'all') return rows;
    const cutoff = new Date(Date.now() - parseInt(this.selectedPeriod, 10) * 86400000);
    return rows.filter(r => r.startedAt && r.startedAt >= cutoff);
  }

  _computeKpis(rows) {
    const total     = rows.length;
    const failed    = rows.filter(r => r.status === 'Failed' || r.status === 'Cancelled').length;
    const running   = rows.filter(r => r.status === 'Running').length;
    const totalRec  = rows.reduce((s, r) => s + r.processed, 0);
    const totalFail = rows.reduce((s, r) => s + r.failed, 0);
    const rate      = totalRec > 0 ? (Math.max(0, totalRec - totalFail) / totalRec) * 100 : 0;
    const durRows   = rows.filter(r => r.durationMs > 0);
    const avgMs     = durRows.length ? durRows.reduce((s, r) => s + r.durationMs, 0) / durRows.length : 0;

    let trend = 0;
    let trendLabel = '';
    if (this.selectedPeriod !== 'all') {
      const days     = parseInt(this.selectedPeriod, 10);
      const cutoff   = new Date(Date.now() - days * 86400000);
      const prev     = new Date(Date.now() - 2 * days * 86400000);
      const prevRows = this._normalize(this.executions)
        .filter(r => r.startedAt && r.startedAt >= prev && r.startedAt < cutoff);
      trend = prevRows.length > 0 ? Math.round(((total - prevRows.length) / prevRows.length) * 100) : 0;
      if (trend !== 0) {
        trendLabel = (trend > 0 ? '+' : '') + trend + '% vs prev. period';
      }
    }

    this.kpis = {
      total,
      successRate:  rate.toFixed(1) + '%',
      totalRecords: this._fmt(totalRec),
      avgDuration:  this._fmtDuration(avgMs),
      failed,
      running,
      trend,
      trendLabel
    };
  }

  _computeStatusDonut(rows) {
    const counts  = {};
    rows.forEach(r => { counts[r.status] = (counts[r.status] || 0) + 1; });
    const total   = rows.length || 1;
    const entries = Object.entries(counts).sort((a, b) => b[1] - a[1]);
    const circ    = 2 * Math.PI * 50;
    let cumAngle  = 0;

    this.statusDonutSlices = entries.map(function(entry) {
      const status = entry[0];
      const count  = entry[1];
      const pct    = count / total;
      const rotate = cumAngle * 360;
      cumAngle    += pct;
      const color  = STATUS_COLORS[status] || '#94a3b8';
      return {
        id:          status,
        color:       color,
        dasharray:   (circ * pct) + ' ' + (circ * (1 - pct)),
        offset:      circ * 0.25,
        pct:         Math.round(pct * 100),
        rotateStyle: 'transform: rotate(' + rotate + 'deg); transform-origin: 60px 60px;'
      };
    });

    this.statusLegend = entries.map(function(entry) {
      const status = entry[0];
      const count  = entry[1];
      const color  = STATUS_COLORS[status] || '#94a3b8';
      const map = {
        Completed: LABELS.legendCompleted,
        Running:   LABELS.legendRunning,
        Failed:    LABELS.legendFailed,
        Cancelled: LABELS.legendCancelled,
        Draft:     LABELS.legendDraft
      };
      return {
        id:       status,
        label:    map[status] || status,
        count:    count,
        pct:      Math.round((count / total) * 100),
        dotStyle: 'background: ' + color + ';'
      };
    });
  }

  _computeVolumeBars(rows) {
    if (!rows.length) { this.volumeBars = []; return; }
    const days     = parseInt(this.selectedPeriod, 10) || 30;
    const groups   = this._groupByDay(rows, days);
    const maxCount = Math.max.apply(null, Object.values(groups).map(function(g) { return g.length; }).concat([1]));

    this.volumeBars = Object.entries(groups).map(function(entry, i) {
      const day   = entry[0];
      const items = entry[1];
      const h     = Math.max(4, (items.length / maxCount) * 100);
      const d     = new Date(day + 'T12:00:00Z');
      return {
        id:       day + i,
        label:    (d.getUTCMonth() + 1) + '/' + d.getUTCDate(),
        count:    items.length,
        barStyle: 'height: ' + h + '%;'
      };
    });
  }

  _computeDurationBars(rows) {
    const withDur = rows.filter(r => r.durationMs > 0 && r.project);
    if (!withDur.length) { this.durationBars = []; return; }

    const byProject = {};
    withDur.forEach(r => {
      if (!byProject[r.project]) byProject[r.project] = [];
      byProject[r.project].push(r.durationMs);
    });

    const avgs = Object.entries(byProject)
      .map(function(e) { return { project: e[0], avg: e[1].reduce((s, d) => s + d, 0) / e[1].length }; })
      .sort((a, b) => b.avg - a.avg)
      .slice(0, 8);

    const max = Math.max.apply(null, avgs.map(a => a.avg).concat([1]));

    this.durationBars = avgs.map((a, i) => {
      const color = CHART_PALETTE[i % CHART_PALETTE.length];
      return {
        id:        a.project + i,
        label:     a.project.length > 16 ? a.project.slice(0, 14) + '...' : a.project,
        text:      this._fmtDuration(a.avg),
        fillStyle: 'width: ' + Math.max(4, (a.avg / max) * 100) + '%; background: ' + color + ';'
      };
    });
  }

  _computeSuccessTrend(rows) {
    if (rows.length < 2) { this.successTrendPoints = []; this._trendRates = []; return; }
    const sorted  = rows.filter(r => r.startedAt).slice().sort((a, b) => a.startedAt - b.startedAt);
    const days    = parseInt(this.selectedPeriod, 10) || 30;
    const groups  = this._groupByDay(sorted, days);
    const entries = Object.entries(groups);
    if (entries.length < 2) { this.successTrendPoints = []; this._trendRates = []; return; }

    const points = entries.map(function(e) {
      const items     = e[1];
      const totalRec  = items.reduce((s, r) => s + r.processed, 0);
      const failedRec = items.reduce((s, r) => s + r.failed, 0);
      return { day: e[0], rate: totalRec > 0 ? ((totalRec - failedRec) / totalRec) * 100 : 0 };
    });

    this._trendRates = points.map(p => p.rate);

    const W = 400, H = 140, pad = 14;
    const pts = points.map((p, i) => ({
      x:    pad + (i / (points.length - 1)) * (W - 2 * pad),
      y:    H - pad - (p.rate / 100) * (H - 2 * pad),
      rate: p.rate,
      day:  p.day
    }));

    const linePath = pts.map((p, i) => (i === 0 ? 'M' : 'L') + p.x + ',' + p.y).join(' ');
    const fillPath = linePath + ' L' + pts[pts.length - 1].x + ',' + H + ' L' + pts[0].x + ',' + H + ' Z';

    this.successTrendPoints = [{ linePath: linePath, fillPath: fillPath, points: pts }];
  }

  _computeTopProjects(rows) {
    const byProject = {};
    rows.forEach(r => {
      if (!byProject[r.project]) {
        byProject[r.project] = { project: r.project, count: 0, records: 0, failed: 0, durSum: 0, durCount: 0 };
      }
      const p = byProject[r.project];
      p.count++;
      p.records += r.processed;
      p.failed  += r.failed;
      if (r.durationMs > 0) { p.durSum += r.durationMs; p.durCount++; }
    });

    const sorted = Object.values(byProject).sort((a, b) => b.count - a.count).slice(0, 10);
    const maxCount = sorted.length ? sorted[0].count : 1;

    this.topProjects = sorted.map((p, i) => {
      const rate      = p.records > 0 ? (p.records - p.failed) / p.records * 100 : 0;
      const avg       = p.durCount > 0 ? p.durSum / p.durCount : 0;
      const rateColor = rate >= 90 ? '#10b981' : rate >= 70 ? '#f59e0b' : '#ef4444';
      return {
        id:            p.project + i,
        rank:          i + 1,
        project:       p.project,
        count:         p.count,
        records:       this._fmt(p.records),
        rate:          rate.toFixed(1) + '%',
        avgDur:        this._fmtDuration(avg),
        rateClass:     rate >= 90 ? 'is-rate-good' : rate >= 70 ? 'is-rate-ok' : 'is-rate-bad',
        rateFillStyle: 'width: ' + Math.min(rate, 100) + '%; background: ' + rateColor + ';'
      };
    });

    // Project exec bars
    this.projectExecBars = sorted.map((p, i) => {
      const color = CHART_PALETTE[i % CHART_PALETTE.length];
      return {
        id:        p.project + '_bar_' + i,
        label:     p.project.length > 18 ? p.project.slice(0, 16) + '...' : p.project,
        text:      String(p.count),
        fillStyle: 'width: ' + Math.max(4, (p.count / maxCount) * 100) + '%; background: ' + color + ';'
      };
    });
  }

  _computeObjectBars(rows) {
    const byObj = {};
    rows.forEach(r => { byObj[r.targetObj] = (byObj[r.targetObj] || 0) + r.processed; });
    const sorted = Object.entries(byObj).sort((a, b) => b[1] - a[1]).slice(0, 8);
    const max    = Math.max.apply(null, sorted.map(e => e[1]).concat([1]));

    this.objectBars = sorted.map((entry, i) => {
      const obj   = entry[0];
      const val   = entry[1];
      const color = CHART_PALETTE[i % CHART_PALETTE.length];
      return {
        id:        obj + i,
        label:     obj.length > 20 ? obj.slice(0, 18) + '...' : obj,
        text:      this._fmt(val),
        fillStyle: 'width: ' + Math.max(4, (val / max) * 100) + '%; background: ' + color + ';'
      };
    });
  }

  // -- Helpers --
  _groupByDay(rows, days) {
    const groups = {};
    const cutoff = days && days > 0 ? new Date(Date.now() - days * 86400000) : null;
    rows.forEach(r => {
      if (!r.startedAt) return;
      if (cutoff && r.startedAt < cutoff) return;
      const key = r.startedAt.toISOString().slice(0, 10);
      if (!groups[key]) groups[key] = [];
      groups[key].push(r);
    });
    return groups;
  }

  _fmt(n) {
    if (n >= 1e6) return (n / 1e6).toFixed(1) + 'M';
    if (n >= 1e3) return (n / 1e3).toFixed(1) + 'K';
    return String(n);
  }

  _fmtDuration(ms) {
    if (!ms || ms <= 0) return '-';
    const s = Math.floor(ms / 1000);
    const m = Math.floor(s / 60);
    const h = Math.floor(m / 60);
    if (h > 0) return h + 'h ' + (m % 60) + 'm';
    if (m > 0) return m + 'm ' + (s % 60) + 's';
    return s + 's';
  }

  _toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}