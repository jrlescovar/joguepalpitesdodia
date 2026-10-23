// dayId is the Arena date supplied by the server, already in Brasilia time.
export function arenaWeekOpening(dayId:string):{view:'standings'|'bracket';stage:0|1|2}{
 const weekday=new Date(`${dayId}T12:00:00Z`).getUTCDay();
 return {view:weekday===0||weekday>=5?'bracket':'standings',stage:weekday===0?2:weekday===6?1:0};
}
