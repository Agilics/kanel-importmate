import { LightningElement, api } from 'lwc';

export default class PaginatorComponent extends LightningElement {
    @api items = [];
    @api pageSize;
    @api pageIndex;

    // ===== Pagination Parameters =====
    get totalPages() {
        return Math.max(1, Math.ceil(this.items.length / this.pageSize));
    }

    get isFirstPage() {
        return this.pageIndex === 1;
    }

    get isLastPage() {
        return this.pageIndex >= this.totalPages;
    }

    get showingOnPage() {
        if (!Array.isArray(this.items) || this.items.length === 0) {
            return 0;
        }

        // Calculer combien d'éléments sont visibles sur cette page
        const start = (this.pageIndex - 1) * this.pageSize;
        const end = start + this.pageSize;
        return Math.min(end, this.items.length) - start;
    }



  
   
    get totalEntries() {
        return this.items.length;
    }

    get pageNumbers() {
        const total = this.totalPages;
        const current = this.pageIndex;
        const out = [];

        const pushPage = (n) => out.push({
            key: `p-${n}`,
            label: String(n),
            page: n,
            isActive: n === current,
            buttonClass: n === current
                ? 'pagination-btn pagination-btn--page pagination-btn--active'
                : 'pagination-btn pagination-btn--page',
            isEllipsis: false
        });

        const pushEllipsis = (pos) => out.push({
            key: `e-${pos}-${out.length}`,
            label: '…',
            isEllipsis: true
        });

        if (total <= 7) {
            for (let i = 1; i <= total; i++) pushPage(i);
            return out;
        }

        pushPage(1);

        const start = Math.max(2, current - 1);
        const end = Math.min(total - 1, current + 1);

        if (start > 2) pushEllipsis('left');
        for (let i = start; i <= end; i++) pushPage(i);
        if (end < total - 1) pushEllipsis('right');

        pushPage(total);

        return out;
    }

    // ===== Pagination Actions =====

    //Dispatch event when page changes
    handlePageChange(newPage) {
        this.dispatchEvent(
            new CustomEvent('pagechange', {
                detail: { pageIndex: newPage }
            })
        );
    }

    //On Navigation to previous page
    gotoPreviousPage() {
        if (!this.isFirstPage) {
            this.handlePageChange(this.pageIndex - 1);
        } 
    }

    //On Navigation to next page
    gotoNextPage() {
        if (!this.isLastPage) {
            this.handlePageChange(this.pageIndex + 1);
        }
    }

    //On Navigation to specific page
    gotoPage(event) {
        const page = Number(event.currentTarget?.dataset?.page);
        if (!Number.isNaN(page)) {
            this.handlePageChange(page);
        } 
    }

    get hasItems() {
        return this.items.length > 0;
    }

    get showNavigationButtons() {
        return this.totalPages > 1;
    }

    //Page number class
    get paginationClass() {
        return this.showNavigationButtons ? 'pagination-pages is-centered' : 'pagination-pages';
    }
    
    get paginationWrapperClass() {
        return this.showNavigationButtons ? 'pagination-wrapper' : 'pagination-wrapper pagination-wrapper--single';
    }
}
