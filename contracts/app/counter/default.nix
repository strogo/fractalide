{stdenv, buildFractalideContract, upkeepers, ...}:

buildFractalideContract rec {
  src = ./.;

  meta = with stdenv.lib; {
    description = "Contract: Describes the Counter model";
    homepage = https://github.com/fractalide/fractalide/tree/master/contracts/fbp/graph;
    license = with licenses; [ mpl20 ];
    maintainers = with upkeepers; [ dmichiels sjmackenzie];
  };
}