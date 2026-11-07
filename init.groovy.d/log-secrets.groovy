import jenkins.model.Jenkins

Thread.start {
    // Wait until nodes are loaded
    sleep(5000)
    println("==========================================================")
    println(" CODEALPHA INBOUND AGENT SECRETS ")
    println("==========================================================")
    Jenkins.instance.nodes.each { node ->
        def computer = node.toComputer()
        if (computer != null) {
            println("AGENT_NAME: " + node.name + " | SECRET: " + computer.getJnlpMac())
        }
    }
    println("==========================================================")
}
