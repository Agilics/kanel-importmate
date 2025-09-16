//Custom Exception Handler
public class ImportException extends Exception {
  //constructors which allows to handle Exceptions on
  public ImportException(Exception e, string sourceClass) {
    system.debug('Exeption Name ******' + e);
  }
}