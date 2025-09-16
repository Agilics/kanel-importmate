public virtual class ApplicationException extends Exception {

    public static void handleError(Exception ex) {
        if (ex instanceof ApplicationException) {
            throw (ApplicationException)ex;
        }
        throw new ApplicationException(ex.getMessage());
    }
}