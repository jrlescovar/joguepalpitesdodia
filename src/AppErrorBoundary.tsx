import { Component, type ReactNode } from 'react';

export default class AppErrorBoundary extends Component<{children:ReactNode},{failed:boolean}> {
  state={failed:false};
  static getDerivedStateFromError() { return {failed:true}; }
  private chunkUnavailable = () => this.setState({failed:true});
  componentDidMount() { window.addEventListener('palpites:chunk-unavailable',this.chunkUnavailable); }
  componentWillUnmount() { window.removeEventListener('palpites:chunk-unavailable',this.chunkUnavailable); }
  render() {
    if(this.state.failed) return <section className="card app-recovery" role="alert" style={{padding:24,margin:'24px auto',maxWidth:520}}>
      <h2>Não foi possível abrir esta tela.</h2>
      <p className="muted">Tente abrir novamente. Se continuar, recarregue para buscar a versão atual do site.</p>
      <div className="flex gap-2" style={{flexWrap:'wrap'}}>
        <button className="primary-button" onClick={()=>this.setState({failed:false})}>Tentar novamente</button>
        <button className="secondary-button" onClick={()=>window.location.reload()}>Recarregar site</button>
      </div>
    </section>;
    return this.props.children;
  }
}
