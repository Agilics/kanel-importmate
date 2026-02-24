/**
 *  @description       : Data source selector page - shows selection cards for CSV or SOQL
 *  @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 *  @group             : 
 *  @last modified on  : 02-23-2026
 *  @last modified by  : Mouhamed NIANG
 *  @Last Modification: Add custom labels
-->
 */
import { LightningElement, api } from 'lwc';

// Page labels
import DATASOURCE_TITLE       from '@salesforce/label/c.DataSource_Title';
import DATASOURCE_SUBTITLE    from '@salesforce/label/c.DataSource_Subtitle';

// File Upload card labels
import FILE_UPLOAD_TITLE      from '@salesforce/label/c.DataSource_FileUpload_Title';
import FILE_UPLOAD_DESCRIPTION from '@salesforce/label/c.DataSource_FileUpload_Description';
import FILE_UPLOAD_FEATURE1   from '@salesforce/label/c.DataSource_FileUpload_Feature1';
import FILE_UPLOAD_FEATURE2   from '@salesforce/label/c.DataSource_FileUpload_Feature2';
import FILE_UPLOAD_FEATURE3   from '@salesforce/label/c.DataSource_FileUpload_Feature3';

// Salesforce Query card labels
import QUERY_TITLE            from '@salesforce/label/c.DataSource_SalesforceQuery_Title';
import QUERY_DESCRIPTION      from '@salesforce/label/c.DataSource_SalesforceQuery_Description';
import QUERY_FEATURE1         from '@salesforce/label/c.DataSource_SalesforceQuery_Feature1';
import QUERY_FEATURE2         from '@salesforce/label/c.DataSource_SalesforceQuery_Feature2';
import QUERY_FEATURE3         from '@salesforce/label/c.DataSource_SalesforceQuery_Feature3';

// Navigation
import BACK_BUTTON            from '@salesforce/label/c.DataSource_Back_Button';

export default class DataSource extends LightningElement {

    // Expose all labels to the template
    label = {
        title           : DATASOURCE_TITLE,
        subtitle        : DATASOURCE_SUBTITLE,
        uploadTitle     : FILE_UPLOAD_TITLE,
        uploadSubtitle  : FILE_UPLOAD_DESCRIPTION, 
        queryTitle      : QUERY_TITLE,
        querySubTitle   : QUERY_DESCRIPTION, 
        back            : BACK_BUTTON
    };

   
    // Data source selector card's parameters for File Upload
    get uploadContents() {
        return [
            { Id: 1, Name: FILE_UPLOAD_FEATURE1 },
            { Id: 2, Name: FILE_UPLOAD_FEATURE2 },
            { Id: 3, Name: FILE_UPLOAD_FEATURE3 }
        ];
    }

    // Data source selector card's parameters for Query Builder
    get queryContents() {
        return [
            { Id: 1, Name: QUERY_FEATURE1 },
            { Id: 2, Name: QUERY_FEATURE2 },
            { Id: 3, Name: QUERY_FEATURE3 }
        ];
    }

    isUpload    = true;
    isNotUpload = false;

    @api currentProject;

    get projectName() {
        return this.currentProject?.Name || '';
    }

    /**
     * Handle CSV source selection
     */
    handleCSV() {
        this.dispatchEvent(
            new CustomEvent('sourceselected', {
                detail  : { source: 'CSV' },
                bubbles : true,
                composed: true
            })
        );
    }

    /**
     * Handle SOQL source selection
     */
    handleSOQL() {
        this.dispatchEvent(
            new CustomEvent('sourceselected', {
                detail  : { source: 'SOQL' },
                bubbles : true,
                composed: true
            })
        );
    }

    handleBackToProjectSetup() {
        this.dispatchEvent(new CustomEvent('previous'));
    }
}