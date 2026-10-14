import { LightningElement, track } from 'lwc';

const WEEKS = [
    { label: 'S-4', ok: 6200, err: 180 },
    { label: 'S-3', ok: 8400, err: 90  },
    { label: 'S-2', ok: 7100, err: 310 },
    { label: 'S-1', ok: 9800, err: 55  },
    { label: 'Cette sem.', ok: 11200, err: 135 }
];

export default class AnalyticsCmp extends LightningElement {
    @track activePeriod = '30j';

    // KPI data wired from Apex (falls back to mock if not available)
    @track kpi = {
        totalRecords : 48200,
        successRate  : 98.4,
        executions   : 48,
        avgDuration  : '1m 48s'
    };

    @track objectBreakdown = [
        { name: 'Account',     val: '19 800', pct: 41, fillStyle: 'width:41%' },
        { name: 'Lead',        val: '14 400', pct: 30, fillStyle: 'width:30%;background:var(--grad-green)' },
        { name: 'Opportunity', val: '8 640',  pct: 18, fillStyle: 'width:18%;background:var(--grad-coral)' },
        { name: 'Contact',     val: '3 360',  pct: 7,  fillStyle: 'width:7%;background:var(--grad-amber)' },
        { name: 'Case',        val: '2 000',  pct: 4,  fillStyle: 'width:4%;background:rgba(148,163,184,.5)' }
    ];

    @track recentActivity = [
        { id: '1', icon: '✅', dotStyle: 'background:rgba(16,185,129,0.1)',  title: 'Import Contacts Q2 terminé',           sub: '1 174 records · Account',     time: 'il y a 2h' },
        { id: '2', icon: '✅', dotStyle: 'background:rgba(16,185,129,0.1)',  title: 'Migration Leads 2025 terminée',         sub: '12 400 records · Lead',        time: 'hier'      },
        { id: '3', icon: '❌', dotStyle: 'background:rgba(244,63,94,0.08)',  title: 'Export Accounts EMEA — échec',          sub: 'Timeout API · Account',        time: '12 mai'    },
        { id: '4', icon: '📅', dotStyle: 'background:rgba(79,70,229,0.08)', title: 'Planification Contacts Daily créée',    sub: 'Quotidien · 08:00 · Contact',  time: '11 mai'    },
        { id: '5', icon: '✅', dotStyle: 'background:rgba(16,185,129,0.1)',  title: 'Sync Opportunités Q2 terminée',         sub: '3 840 records · Opportunity',  time: '10 mai'    }
    ];

    get periods() {
        return ['7j', '30j', '3m', '1an'].map(p => ({
            key: p,
            label: p,
            cls: 'period-btn' + (p === this.activePeriod ? ' active' : '')
        }));
    }

    get barChartData() {
        const max = Math.max(...WEEKS.map(w => w.ok + w.err));
        return WEEKS.map(w => ({
            label   : w.label,
            okH     : ((w.ok  / max) * 100).toFixed(1),
            errH    : ((w.err / max) * 100).toFixed(1),
            okStyle : `height:${((w.ok  / max) * 100).toFixed(1)}%`,
            errStyle: `height:${((w.err / max) * 100).toFixed(1)}%`,
            okVal   : w.ok.toLocaleString('fr'),
            errVal  : w.err
        }));
    }

    get donutStyle() {
        const ok = this.kpi.successRate;
        return `background: conic-gradient(var(--green) 0% ${ok}%, var(--coral) ${ok}% 100%)`;
    }

    get failedRecords() {
        return Math.round(this.kpi.totalRecords * (1 - this.kpi.successRate / 100)).toLocaleString('fr');
    }

    get validRecords() {
        return Math.round(this.kpi.totalRecords * this.kpi.successRate / 100).toLocaleString('fr');
    }

    get totalRecordsFormatted() {
        return this.kpi.totalRecords.toLocaleString('fr');
    }

    handlePeriod(evt) {
        this.activePeriod = evt.currentTarget.dataset.period;
    }
}