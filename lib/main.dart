
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const ChessApp());

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Royal Chess',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B1020),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C5CFC), brightness: Brightness.dark),
      fontFamily: 'sans',
    ),
    home: const ChessPage(),
  );
}

enum Side { white, black }
enum Difficulty { easy, medium, hard }

class Piece {
  final String type;
  final Side side;
  const Piece(this.type, this.side);
  String get symbol {
    const w = {'K':'♔','Q':'♕','R':'♖','B':'♗','N':'♘','P':'♙'};
    const b = {'K':'♚','Q':'♛','R':'♜','B':'♝','N':'♞','P':'♟'};
    return (side == Side.white ? w : b)[type]!;
  }
  Piece copy() => Piece(type, side);
}

class Move {
  final int from, to;
  final Piece? promotion;
  final bool castle, enPassant;
  const Move(this.from, this.to, {this.promotion, this.castle=false, this.enPassant=false});
}

class BoardState {
  List<Piece?> board;
  Side turn;
  int? ep;
  bool wK, wQ, bK, bQ;
  BoardState(this.board, this.turn, {this.ep, this.wK=true, this.wQ=true, this.bK=true, this.bQ=true});
  BoardState clone() => BoardState(board.map((p)=>p?.copy()).toList(), turn, ep: ep, wK:wK,wQ:wQ,bK:bK,bQ:bQ);
}

class ChessGame {
  BoardState state;
  ChessGame(): state = BoardState(_initial(), Side.white);

  static List<Piece?> _initial() {
    final b = List<Piece?>.filled(64, null);
    const order=['R','N','B','Q','K','B','N','R'];
    for(int c=0;c<8;c++){
      b[c]=Piece(order[c],Side.black); b[8+c]=const Piece('P',Side.black);
      b[48+c]=const Piece('P',Side.white); b[56+c]=Piece(order[c],Side.white);
    }
    return b;
  }

  int row(int s)=>s>>3; int col(int s)=>s&7;
  bool inside(int r,int c)=>r>=0&&r<8&&c>=0&&c<8;
  int sq(int r,int c)=>r*8+c;

  bool attacked(BoardState s, int target, Side by) {
    final tr=row(target), tc=col(target);
    for(int i=0;i<64;i++){
      final p=s.board[i]; if(p==null||p.side!=by) continue;
      final r=row(i),c=col(i), dr=tr-r,dc=tc-c;
      if(p.type=='P'){
        final d=by==Side.white?-1:1;
        if(dr==d && dc.abs()==1) return true;
      } else if(p.type=='N'){
        if((dr.abs()==2&&dc.abs()==1)||(dr.abs()==1&&dc.abs()==2)) return true;
      } else if(p.type=='K'){
        if(dr.abs()<=1&&dc.abs()<=1&&(dr!=0||dc!=0)) return true;
      } else {
        final diag=dr.abs()==dc.abs(), straight=(dr==0)^(dc==0);
        final ok=(p.type=='B'&&diag)||(p.type=='R'&&straight)||(p.type=='Q'&&(diag||straight));
        if(ok){
          final sr=dr==0?0:dr.sign, sc=dc==0?0:dc.sign;
          var rr=r+sr,cc=c+sc, clear=true;
          while(rr!=tr||cc!=tc){ if(s.board[sq(rr,cc)]!=null){clear=false;break;} rr+=sr;cc+=sc; }
          if(clear)return true;
        }
      }
    }
    return false;
  }

  bool inCheck(BoardState s, Side side) {
    final k=s.board.indexWhere((p)=>p?.type=='K'&&p?.side==side);
    return k>=0 && attacked(s,k, side==Side.white?Side.black:Side.white);
  }

  List<Move> pseudo(BoardState s, Side side) {
    final out=<Move>[];
    for(int i=0;i<64;i++){
      final p=s.board[i]; if(p==null||p.side!=side)continue;
      final r=row(i),c=col(i);
      void add(int nr,int nc,{bool castle=false,bool ep=false}) {
        if(!inside(nr,nc))return;
        final j=sq(nr,nc), q=s.board[j];
        if(q==null||q.side!=side) out.add(Move(i,j,castle:castle,enPassant:ep));
      }
      if(p.type=='P'){
        final d=side==Side.white?-1:1, start=side==Side.white?6:1;
        final nr=r+d;
        if(inside(nr,c)&&s.board[sq(nr,c)]==null){
          final to=sq(nr,c);
          if(nr==0||nr==7) for(final t in ['Q','R','B','N'])out.add(Move(i,to,promotion:Piece(t,side)));
          else out.add(Move(i,to));
          if(r==start&&s.board[sq(r+2*d,c)]==null)out.add(Move(i,sq(r+2*d,c)));
        }
        for(final dc in [-1,1]){
          if(!inside(nr,c+dc))continue;
          final j=sq(nr,c+dc), q=s.board[j];
          if(q!=null&&q.side!=side){
            if(nr==0||nr==7)for(final t in ['Q','R','B','N'])out.add(Move(i,j,promotion:Piece(t,side)));
            else out.add(Move(i,j));
          } else if(s.ep==j) out.add(Move(i,j,enPassant:true));
        }
      } else if(p.type=='N'){
        for(final d in [[2,1],[2,-1],[-2,1],[-2,-1],[1,2],[1,-2],[-1,2],[-1,-2]])add(r+d[0],c+d[1]);
      } else if(p.type=='K'){
        for(int dr=-1;dr<=1;dr++)for(int dc=-1;dc<=1;dc++)if(dr!=0||dc!=0)add(r+dr,c+dc);
        final enemy=side==Side.white?Side.black:Side.white;
        if(!inCheck(s,side)){
          final canK=side==Side.white?s.wK:s.bK, canQ=side==Side.white?s.wQ:s.bQ;
          if(canK&&s.board[sq(r,5)]==null&&s.board[sq(r,6)]==null&&!attacked(s,sq(r,5),enemy)&&!attacked(s,sq(r,6),enemy))
            out.add(Move(i,sq(r,6),castle:true));
          if(canQ&&s.board[sq(r,1)]==null&&s.board[sq(r,2)]==null&&s.board[sq(r,3)]==null&&!attacked(s,sq(r,3),enemy)&&!attacked(s,sq(r,2),enemy))
            out.add(Move(i,sq(r,2),castle:true));
        }
      } else {
        final dirs=<List<int>>[];
        if(p.type=='B'||p.type=='Q')dirs.addAll([[1,1],[1,-1],[-1,1],[-1,-1]]);
        if(p.type=='R'||p.type=='Q')dirs.addAll([[1,0],[-1,0],[0,1],[0,-1]]);
        for(final d in dirs){
          var nr=r+d[0],nc=c+d[1];
          while(inside(nr,nc)){
            final j=sq(nr,nc),q=s.board[j];
            if(q==null)out.add(Move(i,j)); else {if(q.side!=side)out.add(Move(i,j));break;}
            nr+=d[0];nc+=d[1];
          }
        }
      }
    }
    return out;
  }

  List<Move> legal(BoardState s, Side side) {
    final out=<Move>[];
    for(final m in pseudo(s,side)){
      final n=apply(s,m);
      if(!inCheck(n,side))out.add(m);
    }
    return out;
  }

  BoardState apply(BoardState s, Move m) {
    final n=s.clone(); final p=n.board[m.from]!;
    n.board[m.from]=null; n.ep=null;
    if(m.enPassant){
      final rr=row(m.to)+(p.side==Side.white?1:-1);
      n.board[sq(rr,col(m.to))]=null;
    }
    if(m.castle){
      final r=row(m.from);
      if(col(m.to)==6){ n.board[sq(r,5)]=n.board[sq(r,7)]; n.board[sq(r,7)]=null; }
      else { n.board[sq(r,3)]=n.board[sq(r,0)]; n.board[sq(r,0)]=null; }
    }
    n.board[m.to]=m.promotion??p;
    if(p.type=='P'&&(row(m.to)-row(m.from)).abs()==2)n.ep=sq((row(m.to)+row(m.from))~/2,col(m.from));
    if(p.type=='K'){if(p.side==Side.white){n.wK=false;n.wQ=false;}else{n.bK=false;n.bQ=false;}}
    if(p.type=='R'){
      if(m.from==56)n.wQ=false;if(m.from==63)n.wK=false;if(m.from==0)n.bQ=false;if(m.from==7)n.bK=false;
    }
    final captured=s.board[m.to];
    if(captured?.type=='R'){
      if(m.to==56)n.wQ=false;if(m.to==63)n.wK=false;if(m.to==0)n.bQ=false;if(m.to==7)n.bK=false;
    }
    n.turn=p.side==Side.white?Side.black:Side.white;
    return n;
  }

  String status(BoardState s) {
    final moves=legal(s,s.turn);
    if(moves.isEmpty)return inCheck(s,s.turn)?(s.turn==Side.white?'Black wins by checkmate':'White wins by checkmate'):'Draw by stalemate';
    if(s.board.whereType<Piece>().length==2)return 'Draw by insufficient material';
    return inCheck(s,s.turn)?'Check!':'';
  }
}

class AI {
  final ChessGame game=ChessGame();
  final Random rng=Random();
  int depth(Difficulty d)=>d==Difficulty.easy?1:d==Difficulty.medium?2:3;

  int pieceValue(String t)=>{'P':100,'N':320,'B':330,'R':500,'Q':900,'K':20000}[t]!;
  int evaluate(BoardState s){
    var score=0;
    for(int i=0;i<64;i++){
      final p=s.board[i];if(p==null)continue;
      var v=pieceValue(p.type);
      final r=i>>3,c=i&7;
      if(p.type=='P')v+= (p.side==Side.black?r:7-r)*7;
      if(p.type=='N'||p.type=='B')v+= (3.5-c).abs()<2 && (3.5-r).abs()<3 ? 12:0;
      score+=p.side==Side.black?v:-v;
    }
    return score;
  }

  int minimax(BoardState s,int d,int alpha,int beta,bool maximizing){
    final moves=game.legal(s,s.turn);
    if(d==0||moves.isEmpty()){
      if(moves.isEmpty()&&game.inCheck(s,s.turn)) return s.turn==Side.black?100000+d:-100000-d;
      return evaluate(s);
    }
    if(maximizing){
      var best=-1000000;
      for(final m in moves){best=max(best,minimax(game.apply(s,m),d-1,alpha,beta,false));alpha=max(alpha,best);if(beta<=alpha)break;}
      return best;
    }else{
      var best=1000000;
      for(final m in moves){best=min(best,minimax(game.apply(s,m),d-1,alpha,beta,true));beta=min(beta,best);if(beta<=alpha)break;}
      return best;
    }
  }

  Move choose(BoardState s,Difficulty d){
    final moves=game.legal(s,Side.black);
    if(moves.isEmpty())throw StateError('No legal move');
    if(d==Difficulty.easy)return moves[rng.nextInt(moves.length)];
    var best=-1000000; Move? selected;
    for(final m in moves){
      final score=minimax(game.apply(s,m),depth(d)-1,-1000000,1000000,false);
      if(score>best){best=score;selected=m;}
    }
    return selected!;
  }
}

class ChessPage extends StatefulWidget{
  const ChessPage({super.key});
  @override State<ChessPage> createState()=>_ChessPageState();
}

class _ChessPageState extends State<ChessPage>{
  final chess=ChessGame(); final ai=AI();
  Difficulty difficulty=Difficulty.medium;
  int? selected; List<Move> moves=[];
  bool thinking=false; String message='Your turn';
  final history=<BoardState>[];

  String sqName(int s)=>'${String.fromCharCode(97+(s&7))}${8-(s>>3)}';

  void reset(){
    setState((){chess.state=BoardState(ChessGame._initial(),Side.white);selected=null;moves=[];message='Your turn';history.clear();thinking=false;});
  }

  Future<void> play(Move m) async{
    if(thinking||chess.state.turn!=Side.white)return;
    history.add(chess.state.clone());
    setState((){chess.state=chess.apply(chess.state,m);selected=null;moves=[];});
    final st=chess.status(chess.state);
    if(st.isNotEmpty){setState(()=>message=st);return;}
    setState(()=>thinking=true);
    await Future.delayed(const Duration(milliseconds:250));
    final aiMove=ai.choose(chess.state,difficulty);
    if(!mounted)return;
    history.add(chess.state.clone());
    setState((){chess.state=chess.apply(chess.state,aiMove);thinking=false;message=chess.status(chess.state);});
  }

  void tap(int s){
    if(thinking||chess.state.turn!=Side.white)return;
    final p=chess.state.board[s];
    final hit=moves.where((m)=>m.to==s).toList();
    if(hit.isNotEmpty){play(hit.first);return;}
    if(p?.side==Side.white){
      setState((){selected=s;moves=chess.legal(chess.state,Side.white).where((m)=>m.from==s).toList();});
    }else setState((){selected=null;moves=[];});
  }

  @override Widget build(BuildContext context){
    final w=MediaQuery.of(context).size.width;
    final board=min(w-24,650.0);
    return Scaffold(
      appBar: AppBar(
        title: const Row(children:[Icon(Icons.auto_awesome),SizedBox(width:10),Text('Royal Chess',style:TextStyle(fontWeight:FontWeight.w800))]),
        actions:[IconButton(onPressed:reset,icon:const Icon(Icons.refresh),tooltip:'New game')],
      ),
      body: SafeArea(child:SingleChildScrollView(
        child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760),child:Padding(
          padding:const EdgeInsets.all(12),
          child:Column(children:[
            Row(children:[
              Expanded(child:_InfoCard(icon:Icons.psychology,title:'Opponent',value:difficulty.name.toUpperCase())),
              const SizedBox(width:8),
              Expanded(child:_InfoCard(icon:Icons.timer,title:'Status',value:thinking?'Computer thinking…':(message.isEmpty?'Your turn':message))),
            ]),
            const SizedBox(height:14),
            Container(
              decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),boxShadow:[BoxShadow(blurRadius:25,color:Colors.black.withOpacity(.35))]),
              clipBehavior:Clip.antiAlias,
              child:SizedBox(width:board,height:board,child:GridView.builder(
                physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:8),
                itemCount:64,itemBuilder:(context,i){
                  final r=i>>3,c=i&7, light=(r+c)%2==0;
                  final p=chess.state.board[i], isSel=selected==i, can=moves.any((m)=>m.to==i);
                  return GestureDetector(onTap:()=>tap(i),child:Container(
                    decoration:BoxDecoration(color:light?const Color(0xFFE9D5B5):const Color(0xFF7A5537),border: isSel?Border.all(color:const Color(0xFFB69CFF),width:4):null),
                    child:Stack(alignment:Alignment.center,children:[
                      if(can)Container(width:p==null?18:42,height:p==null?18:42,decoration:BoxDecoration(shape:BoxShape.circle,color:p==null?Colors.black26:Colors.transparent,border:p!=null?Border.all(color:Colors.black38,width:3):null)),
                      if(p!=null)Text(p.symbol,style:TextStyle(fontSize:board/10,color:p.side==Side.white?Colors.white:Colors.black87,shadows:const[Shadow(blurRadius:2,offset:Offset(1,2),color:Colors.black54)])),
                      if(r==7)Positioned(left:3,bottom:2,child:Text(String.fromCharCode(97+c),style:TextStyle(fontSize:10,color:light?Colors.black54:Colors.white54))),
                      if(c==0)Positioned(left:3,top:2,child:Text('${8-r}',style:TextStyle(fontSize:10,color:light?Colors.black54:Colors.white54))),
                    ])));
                },
              )),
            ),
            const SizedBox(height:16),
            Row(children:[
              Expanded(child:Text('Choose difficulty',style:TextStyle(color:Colors.white.withOpacity(.75),fontWeight:FontWeight.w600))),
              DropdownButton<Difficulty>(value:difficulty,onChanged:thinking?null:(v){if(v!=null)setState(()=>difficulty=v);},items:Difficulty.values.map((d)=>DropdownMenuItem(value:d,child:Text(d.name[0].toUpperCase()+d.name.substring(1)))).toList()),
            ]),
            const SizedBox(height:6),
            Row(children:[
              Expanded(child:OutlinedButton.icon(onPressed:history.isEmpty||thinking?null:(){setState((){if(history.isNotEmpty){chess.state=history.removeLast();}selected=null;moves=[];message='Your turn';});},icon:const Icon(Icons.undo),label:const Text('Undo'))),
              const SizedBox(width:10),
              Expanded(child:FilledButton.icon(onPressed:reset,icon:const Icon(Icons.add),label:const Text('New Game'))),
            ]),
            const SizedBox(height:14),
            Text('White: You   •   Black: Computer',style:TextStyle(color:Colors.white.withOpacity(.5))),
          ]),
        ))),
      )),
    );
  }
}

class _InfoCard extends StatelessWidget{
  final IconData icon;final String title,value;
  const _InfoCard({required this.icon,required this.title,required this.value});
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(color:Colors.white.withOpacity(.06),borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.white.withOpacity(.08))),
    child:Row(children:[Icon(icon,size:22,color:const Color(0xFFB69CFF)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:TextStyle(fontSize:11,color:Colors.white.withOpacity(.5))),Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700))]))]),
  );
}
