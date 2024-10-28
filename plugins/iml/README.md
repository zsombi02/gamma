# Integration to Imandra

This folder contains plugins for the mapping of high-level Gamma (composite) models into IML through a symbolic transition systems formalism (xSTS). The plugins provide support for the integration of Gamma and Imandra, that is, the mapping of Gamma models into IML, mapping reachability/invariant properties to Imandra verify/instance calls, and using Imandra instances hosted in the cloud to carry out verification via Imandra's Python API.

## Setup

1. Set up an Eclipse with the [core Gamma plugins](../README.md).
2. Set up [Imandra](https://imandra.ai/). For this, you will need Python 3:
	- Open a command line and use *pip3* to install *Imandra*: `pip install imandra`.
	- Install the [imandra-cli](https://docs.imandra.ai/imandra-docs/notebooks/installation-simple/) client according to your operating system(i.e., `sh <(curl -s "https://storage.googleapis.com/imandra-do/install.sh")` or `(Invoke-WebRequest https://storage.googleapis.com/imandra-do/install.ps1).Content | powershell -`). Create an account using the *imandra-cli* and agree to the community guidelines, i.e., use the following command in a command line after navigating into the home folder of the installed *imandra-cli*: `imandra-cli auth login`.
3. Set up the plugins in this folder.
   - Import all Eclipse projects from this `iml` folder.
   
## Property specification

Gamma supports the specification of _computational tree logic*_ (CTL*) properties in the Gamma Property Language (GPL). CTL* can be considered as a superset of  [_linear-time temporal logic_](https://en.wikipedia.org/wiki/Linear_temporal_logic) (LTL) and _computational tree logic_ (CTL); note that LTL and CTL usually are the subsets directly supported by verification back-ends.

### Linear-time temporal logic (LTL)

In logic, linear-time temporal logic (LTL) is a modal temporal logic with modalities referring to time. LTL allows for encoding formulas about *infinite paths* with respect to the behavior of a system, e.g., a condition will eventually be true or a condition will be true until another fact becomes true, etc. In contrast to other kinds of temporal logics, in LTL, we consider infinite *linear* paths (i.e., every path starting from the initial state of our system) without any possible branching later; hence the name LTL.

Syntactically, LTL formulas are composed of

1. a finite set of atomic propositions (AP) e.g., in the context of statecharts, variable, event and state references, as well as the _true_ and _false_ boolean literals,
1. the logical operators ¬ and ∨, as well as
1. the unary temporal operators **X**, **F** and **G** and binary operator **U**.

The informal semantics of these temporal logic operators, considering valid LTL subformulas ψ and φ, is as follows:

- **X** φ: *neXt*: φ has to hold in the next state. ![X](https://upload.wikimedia.org/wikipedia/commons/1/11/Ltlnext.svg "X semantics")
- **F** φ: *Future*: φ eventually has to hold (somewhere on the subsequent path). ![F](https://upload.wikimedia.org/wikipedia/commons/3/37/Ltleventually.svg "F semantics")
- **G** φ: *Globally*: φ has to hold on the entire subsequent path. ![G](https://upload.wikimedia.org/wikipedia/commons/e/e2/Ltlalways.svg "G semantics")
- ψ **U** φ: *Until*: ψ has to hold at least until φ becomes true, which must hold in the current or a future state. ![U](https://en.wikipedia.org/wiki/Linear_temporal_logic#/media/File:Ltluntil.svg "U semantics")
	- Note that **F** φ ≡ _true_ **U** φ and **F** φ ≡ ¬**F** ¬φ.

