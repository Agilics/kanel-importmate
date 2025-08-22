import { LightningElement, track } from "lwc";

export default class CsvUploader extends LightningElement {
  @track data = []; // Rows
  @track columns = []; // Headers

  handleFileUpload(event) {
    const file = event.target.files[0];
    if (file) {
      let reader = new FileReader();
      reader.onload = () => {
        let text = reader.result;
        this.parseCSV(text);
      };
      reader.readAsText(file);
    }
  }

  parseCSV(csv) {
    let allLines = csv.split(/\r\n|\n/);
    this.columns = allLines[0].split(","); // header row

    this.data = allLines.slice(1).map((line, index) => {
      let rowData = line.split(",");
      return {
        id: index, // unique key
        values: this.columns.map((col, i) => {
          return { key: col + "_" + index, value: rowData[i] || "" };
        })
      };
    });
  }
}
