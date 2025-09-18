public  class ScheduleException  extends Exception{
     public static void handleError(Exception ex) {
        if (ex instanceof ScheduleException) {
            throw (ScheduleException)ex;
        }
        throw new ScheduleException(ex.getMessage());
    }   
}