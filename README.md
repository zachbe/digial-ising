Digital Ising Machines:

Ising machines are very powerful tools for solving optimization problems. There has been a lot of exciting research into ising machines, from probabilistic bits using novel materials to coupled ring oscillators. One thing that all of these designs have in common is that they require dedicated mixed-signal hardware. This means that it’s difficult to scale these sort of designs down to advanced process nodes, making them less viable than conventional digital computers, despite all of their advantages.

This project is an attempt to create an entirely digital coupled ising solver. Instead of using voltage-based coupling, we are trying to use a timing based coupling method where different oscillators control another based on where they are in their phase. We hope that this can allow us to create a fully digital couplings game that can be deployed on an FPGA, and ultimately manufactured in an advanced process node.

How it Works:

When oscillators A and B are positively coupled, the oscillators' relative phases will be changed when they are different.

When oscillators A and B are negatively coupled, the oscillators' relative phases will be changed when they are the same.

Graphics will be added soon.	
