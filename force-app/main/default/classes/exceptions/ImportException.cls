 
/*
 *Import  Project Exception
 */
  
//Custom Exception Handler
public class ImportException extends Exception {
  //constructors which allows to handle Exceptions on
   
  public static void handleError(Exception ex) {
        if (ex instanceof ImportException) {
            throw (ImportException)ex;
        }

        throw new ImportException(ex.getMessage());
    }
} 
