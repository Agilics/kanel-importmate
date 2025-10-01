import { LightningElement } from "lwc";

export default class SimpleComponent extends LightningElement {
  message = "Hello World";

  // Méthode statique simple à tester
  static getGreeting(name) {
    return `Hello ${name}!`;
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> origin/develop2
