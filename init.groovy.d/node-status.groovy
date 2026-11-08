import jenkins.model.Jenkins

Thread.start {
    // Wait until nodes are fully initialized
    sleep(5000)
    println("==========================================================")
    println(" CodeAlpha Node Initialization Status")
    println("==========================================================")
    Jenkins.instance.nodes.each { node ->
        println("Registered Agent Node: " + node.name + " (Labels: " + node.labelString + ")")
    }
    println("Security Notice: Agent secret tokens are strictly accessible")
    println("only via authenticated Controller UI or protected admin API.")
    println("==========================================================")
}
