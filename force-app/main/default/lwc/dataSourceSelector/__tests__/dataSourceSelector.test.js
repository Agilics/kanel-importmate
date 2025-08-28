import { createElement } from '@lwc/engine-dom';
import DataSourceSelector from 'c/dataSourceSelector';

describe('c-data-source-selector', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders two selection cards initially', () => {
        const element = createElement('c-data-source-selector', {
            is: DataSourceSelector
        });
        document.body.appendChild(element);
        const cards = element.shadowRoot.querySelectorAll('.card');
        expect(cards.length).toBe(2);
    });

    it('renders CSV component when CSV card is clicked', async () => {
        const element = createElement('c-data-source-selector', {
            is: DataSourceSelector
        });
        document.body.appendChild(element);

        const cards = element.shadowRoot.querySelectorAll('.card');
        cards[0].click();
        await Promise.resolve();

        const csvComponent = element.shadowRoot.querySelector('c-csv-Uploader');
        expect(csvComponent).not.toBeNull();
    });

    it('renders SOQL component when SOQL card is clicked', async () => {
        const element = createElement('c-data-source-selector', {
            is: DataSourceSelector
        });
        document.body.appendChild(element);

        const cards = element.shadowRoot.querySelectorAll('.card');
        cards[1].click();
        await Promise.resolve();

        const soqlComponent = element.shadowRoot.querySelector('c-soql-builder');
        expect(soqlComponent).not.toBeNull();
    });

    it('emits dataloaded when child fires soqlbuilt', async () => {
        const element = createElement('c-data-source-selector', {
            is: DataSourceSelector
        });
        const handler = jest.fn();
        element.addEventListener('dataloaded', handler);
        document.body.appendChild(element);

        // Click to render SOQL child
        const cards = element.shadowRoot.querySelectorAll('.card');
        cards[1].click();
        await Promise.resolve();

        // Dispatch event from child
        const soqlComponent = element.shadowRoot.querySelector('c-soql-builder');
        const detail = { query: 'SELECT Id FROM Account', results: [] };
        soqlComponent.dispatchEvent(new CustomEvent('soqlbuilt', { detail, bubbles: true }));
        await Promise.resolve();

        expect(handler).toHaveBeenCalledTimes(1);
        expect(handler.mock.calls[0][0].detail).toEqual(detail);
    });
});
