import { LightningElement, track } from 'lwc';

export default class CsvUploader extends LightningElement {
    @track data = [];    // Rows
    @track columns = []; // Headers

    handleFileUpload(event) {
        const file = event.target.files && event.target.files[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = () => {
                const text = reader.result;
                this.parseCSV(text);
            };
            reader.readAsText(file);
        }
    }

    parseCSV(csv) {
        // Split lines by both Windows and Unix line endings
        const allLines = csv.split(/\r\n|\n/);
        if (!allLines || allLines.length === 0) {
            this.data = [];
            this.columns = [];
            return;
        }
        // Header row defines the columns
        this.columns = allLines[0].split(',');
        // Build data rows
        this.data = allLines.slice(1).filter(line => line.trim().length > 0).map((line, index) => {
            const rowData = line.split(',');
            return {
                id: index,
                values: this.columns.map((col, i) => {
                    return { key: `${col}_${index}`, value: rowData[i] || '' };
                })
            };
        });
    }
}
