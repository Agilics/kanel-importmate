//send event utility
export function sendCustomEvent(element, eventName, detail = {}) {
    const event = new CustomEvent(eventName, {
        detail: detail,
        bubbles: true,
        composed: true
    });
    element.dispatchEvent(event);
}

//navigate to page
/* Usage:
   step 1 :  import { navigateToPage } from 'c/utility';
   step 2 : call navigateToPage('ProjectDetails', { projectId: '12345' });
   @pageName: Name of the page to navigate to ['FieldMapping', 'Dashboard','Transformation',
                                              'Validation','Execution','ProjectDetails','DataSource','CSVUpload','SOQLQueryBuilder']
   @params: Object containing key-value pairs of parameters to pass to the page
*/
export function navigateToPage(pageName, params = {}) {
    const event = new CustomEvent('navigate', {
        detail: {
            page: pageName,
            parameters: params
        },
        bubbles: true,
        composed: true
    });
    document.dispatchEvent(event);
}   

export function parseCsvData(csvString) {
    console.log('Parsing CSV data:', csvString);
    if (!csvString || csvString.trim() === '') {
        return [];
    }

    const lines = csvString.trim().split('\n');
    if (lines.length < 2) {
        return [];
    }

    // Detect delimiter from first line (header row)
    const delimiter = detectDelimiter(lines[0]);
    console.log('Detected delimiter:', delimiter);

    // Parse headers from first line - this row will NOT be included in data
    const headers = parseCsvLine(lines[0], delimiter);
    const data = [];

    // Parse data rows - start from index 1 to skip header row
    // Only process non-empty lines with actual data
    for (let i = 1; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line) continue; // Skip empty lines
        
        const values = parseCsvLine(line, delimiter);
        
        // Skip if all values are empty (line with only delimiters)
        const hasData = values.some(val => val && val.trim() !== '');
        if (!hasData) continue;
        
        if (values.length > 0) {
            const row = {};
            headers.forEach((header, index) => {
                row[header] = values[index] || '';
            });
            data.push(row);
        }
    }

    console.log('Parsed CSV data:', JSON.stringify(data));
    return data;
}

export function detectDelimiter(line) {
    const delimiters = [',', ';', '\t', '|'];
    let maxCount = 0;
    let detectedDelimiter = ',';

    for (const delimiter of delimiters) {
        const count = (line.match(new RegExp(`\\${delimiter}`, 'g')) || []).length;
        if (count > maxCount) {
            maxCount = count;
            detectedDelimiter = delimiter;
        }
    }

    return detectedDelimiter;
}

export function parseCsvLine(line, delimiter = ',') {
    const result = [];
    let current = '';
    let inQuotes = false;
    
    for (let i = 0; i < line.length; i++) {
        const char = line[i];
        const nextChar = line[i + 1];
        
        if (char === '"') {
            if (inQuotes && nextChar === '"') {
                // Escaped quote
                current += '"';
                i++; // Skip next quote
            } else {
                // Toggle quote state
                inQuotes = !inQuotes;
            }
        } else if (char === delimiter && !inQuotes) {
            // End of field
            result.push(current.trim());
            current = '';
        } else {
            current += char;
        }
    }
    
    // Add last field
    result.push(current.trim());
    
    return result;
}

/**
 * Sets up a beforeunload handler to warn users when closing the page
 */
export function setupBeforeUnloadWarning(shouldWarn) {
    const handler = (event) => {
        if (shouldWarn && shouldWarn()) {
            const message = 'You have unsaved changes. Are you sure you want to leave?';
            event.preventDefault();
            event.returnValue = message;
            return message;
        }
    };
    
    window.addEventListener('beforeunload', handler);
    
    return () => {
        window.removeEventListener('beforeunload', handler);
    };
}