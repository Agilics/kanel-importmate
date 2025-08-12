import { LightningElement, wire, api } from "lwc";
import getRecentsProjets from "@salesforce/apex/ImportProjectController.getRecentsProjets";
// import static resources

import { loadScript, loadStyle } from 'lightning/platformResourceLoader';  
import fontawesome from '@salesforce/resourceUrl/fontawesome';




export default class MainComponent extends LightningElement {
  @api limitor = 3;

  @wire(getRecentsProjets, { limitor: "$limitor" }) importProjects; // 3 latest import projects


  //load Fontawesome for Icons styles & scripts
  connectedCallback() {
    //code
     Promise.all([
            
                //scripts
                loadScript(this,fontawesome + 'fontawesome.min.js'),
                loadScript(this,fontawesome + 'all.js'), 
                loadScript(this,fontawesome + 'all.min.js'), 
                
                //load style for fontawesome 
               loadStyle(this,fontawesome + '/css/all.min.css')


            ]).then(() => {
                    console.log("failed  to load fontawesome");
                    ; 
            });

  }
}
