export type TournamentProjection<T> = {id:string;phase:'idle'|'loading'|'ready'|'error';data:T|null};
type RequestCapture = {id:string;revision:number;signal:AbortSignal};

// One atomic projection. Every read is bound to both the selected ID and the
// request revision; stale producers cannot publish even if they ignore abort.
export function createTournamentProjectionLoader<T>(publish:(state:TournamentProjection<T>)=>void) {
  let selectedId='', revision=0, disposed=false;
  let phase:TournamentProjection<T>['phase']='idle';
  let controller=new AbortController();
  const publishState=(state:TournamentProjection<T>)=>{phase=state.phase;publish(state);};
  const invalidate=()=>{controller.abort();controller=new AbortController();revision++;};
  const capture=(id:string):RequestCapture|null => !disposed && id && id===selectedId
    ? {id,revision,signal:controller.signal} : null;
  const isCurrent=(request:RequestCapture):boolean => !disposed && request.id===selectedId
    && request.revision===revision && !request.signal.aborted;
  return {
    get selectedId(){return selectedId;},
    get disposed(){return disposed;},
    get phase(){return phase;},
    select(id:string) {
      if(disposed || id===selectedId) return false;
      invalidate();selectedId=id;publishState({id,phase:'idle',data:null});return true;
    },
    capture,isCurrent,
    dispose(){invalidate();disposed=true;},
    resume(){disposed=false;},
    async load(id:string, producer:(signal:AbortSignal)=>Promise<T>):Promise<boolean> {
      if(disposed || !id || id!==selectedId) return false;
      invalidate();const request=capture(id)!;
      publishState({id,phase:'loading',data:null});
      try {
        const data=await producer(request.signal);
        if(!isCurrent(request)) return false;
        publishState({id,phase:'ready',data});return true;
      } catch(error) {
        if(!isCurrent(request)) return false;
        publishState({id,phase:'error',data:null});throw error;
      }
    }
  };
}
