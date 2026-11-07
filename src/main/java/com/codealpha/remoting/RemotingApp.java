package com.codealpha.remoting;

import java.net.InetAddress;
import java.net.UnknownHostException;

/**
 * CodeAlpha Internship Project: Distributed Build Execution Using Jenkins Remoting
 * Sample Java 21 Application executed on remote Jenkins agents.
 */
public class RemotingApp {

    public static void main(String[] args) {
        System.out.println("====================================================");
        System.out.println(" CodeAlpha Distributed Build Execution - Remote Node ");
        System.out.println("====================================================");
        System.out.println("Execution Host: " + getHostname());
        System.out.println("Operating System: " + System.getProperty("os.name") + " (" + System.getProperty("os.arch") + ")");
        System.out.println("Java Version: " + System.getProperty("java.version"));
        System.out.println("User Account: " + System.getProperty("user.name"));
        System.out.println("Current Directory: " + System.getProperty("user.dir"));
        System.out.println("====================================================");
        
        RemotingApp app = new RemotingApp();
        int sum = app.add(40, 2);
        System.out.println("Sample Computation Result: 40 + 2 = " + sum);
        System.out.println("Application Execution Completed Successfully!");
    }

    public int add(int a, int b) {
        return a + b;
    }

    public int multiply(int a, int b) {
        return a * b;
    }

    public boolean isHealthy() {
        return true;
    }

    public static String getHostname() {
        try {
            return InetAddress.getLocalHost().getHostName();
        } catch (UnknownHostException e) {
            return "Unknown-Host";
        }
    }
}
