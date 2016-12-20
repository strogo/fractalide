#[macro_use]
extern crate rustfbp;
extern crate capnp;

agent! {
    input(input: any),
    output(output: any),
    outarr(output: any),
    fn run(&mut self) -> Result<Signal> {
        let msg = try!(self.ports.recv("input"));
        let _ = self.send_action("output", msg);
        Ok(End)
    }
}