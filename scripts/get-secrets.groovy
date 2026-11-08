// scripts/get-secrets.groovy
// Helper executed by Jenkins script console to retrieve node HMAC secrets
jenkins.model.Jenkins.instance.nodes.each { node ->
    def computer = node.toComputer()
    if (computer != null) {
        println("AGENT_NODE:" + node.name + "=" + computer.getJnlpMac())
    }
}
