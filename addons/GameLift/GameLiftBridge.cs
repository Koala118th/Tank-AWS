using Godot;
using Aws.GameLift.Server;
using Aws.GameLift.Server.Model;
using System.Collections.Generic;

public partial class GameLiftBridge : Node
{
    private Node _gdServer;

    private void ConfigureLogging() //Disables log4net console output and configures a file appender for logging
    {
        log4net.Util.LogLog.QuietMode = true;

        var hierarchy =
            (log4net.Repository.Hierarchy.Hierarchy)
            log4net.LogManager.GetRepository();

        var consoleAppender = new log4net.Appender.ConsoleAppender
        {
            Layout = new log4net.Layout.PatternLayout(
                "%date [%thread] %-5level %logger - %message%newline"
            ),
            Threshold = log4net.Core.Level.Warn
        };
        consoleAppender.ActivateOptions();

        var fileAppender = new log4net.Appender.FileAppender
        {
            File = "logs/gamelift-full.log",
            AppendToFile = true,
            Layout = new log4net.Layout.PatternLayout(
                "%date [%thread] %-5level %logger - %message%newline"
            ),
            Threshold = log4net.Core.Level.Debug
        };
        fileAppender.ActivateOptions();

        hierarchy.Root.AddAppender(consoleAppender);
        hierarchy.Root.AddAppender(fileAppender);
        hierarchy.Configured = true;
    }

    public void InitGameLift(int port)
    {
        var args = OS.GetCmdlineArgs();
        bool isServer = System.Array.IndexOf(args, "--server") >= 0
            || DisplayServer.GetName() == "headless";

        if (!isServer)
            return;

        _gdServer = GetNode("/root/GameServer");

        ConfigureLogging();

        const bool IsAnywhereFleet = false;

        var initOutcome = IsAnywhereFleet
        ? GameLiftServerAPI.InitSDK(GetServerParameters())
        : GameLiftServerAPI.InitSDK();

        if (!initOutcome.Success)
        {
            GD.PrintErr(
                "===============================\n" +
                "GameLift InitSDK failed: " +
                initOutcome.Error.ErrorMessage +
                "\n==============================="
            );
            return;
        }

        var logParameters = new LogParameters(
            new List<string>
            {
                "/local/game/logs/myserver.log"
            }
        );

        var processParams = new ProcessParameters(
            OnStartGameSession,
            OnUpdateGameSession,
            OnProcessTerminate,
            OnHealthCheck,
            port,
            logParameters
        );

        var readyOutcome = GameLiftServerAPI.ProcessReady(processParams);

        if (!readyOutcome.Success)
        {
            GD.PrintErr(
                "===============================\n" +
                "ProcessReady failed: " +
                readyOutcome.Error.ErrorMessage +
                "\n==============================="
            );
        }
        else
        {
            GD.Print(
                "===============================\n" +
                "GameLift: ProcessReady succeeded, waiting for a game session..." +
                "\n==============================="
            );
        }
    }

    private ServerParameters GetServerParameters()
    {
        string region = System.Environment.GetEnvironmentVariable("GAMELIFT_REGION");
        string computeLocation = System.Environment.GetEnvironmentVariable("GAMELIFT_LOCATION");
        string fleetId = System.Environment.GetEnvironmentVariable("GAMELIFT_FLEET_ID");
        string authToken = System.Environment.GetEnvironmentVariable("GAMELIFT_AUTH_TOKEN");

        return new ServerParameters(
            region,
            $"process-{System.Guid.NewGuid()}",
            computeLocation,
            fleetId,
            authToken
        );
    }

    public void AcceptPlayerSession(string playerSessionId)
    {
        var acceptOutcome = GameLiftServerAPI.AcceptPlayerSession(playerSessionId);

        if (!acceptOutcome.Success)
        {
            GD.PrintErr(
                "===============================\n" +
                "AcceptPlayerSession failed: " +
                acceptOutcome.Error.ErrorMessage +
                "\n==============================="
            );
        }
        else
        {
            GD.Print(
                "===============================\n" +
                "AcceptPlayerSession succeeded for player session: " +
                playerSessionId +
                "\n==============================="
            );
        }
    }

    public void RemovePlayerSession(string playerSessionId)
    {
        var removeOutcome = GameLiftServerAPI.RemovePlayerSession(playerSessionId);

        if (!removeOutcome.Success)
        {
            GD.PrintErr(
                "===============================\n" +
                "RemovePlayerSession failed: " +
                removeOutcome.Error.ErrorMessage +
                "\n==============================="
            );
        }
        else
        {
            GD.Print(
                "===============================\n" +
                "RemovePlayerSession succeeded for player session: " +
                playerSessionId +
                "\n==============================="
            );
        }
    }

    private void OnStartGameSession(GameSession session)
    {
        GD.Print(
            "===============================\n" +
            "GameLift: game session assigned, starting server..." +
            "\n==============================="
        );

        _gdServer.CallDeferred("start_server");

        var activateOutcome = GameLiftServerAPI.ActivateGameSession();

        if (!activateOutcome.Success)
        {
            GD.PrintErr(
                "===============================\n" +
                "ActivateGameSession failed: " +
                activateOutcome.Error.ErrorMessage +
                "\n==============================="
            );
        }
        else
        {
            GD.Print(
                "===============================\n" +
                "ActivateGameSession succeeded" +
                "\n==============================="
            );

            StartEmptyServerTimer();
        }
    }

    private void OnUpdateGameSession(UpdateGameSession updateGameSession)
    {
        GD.Print(
            "===============================\n" +
            "GameLift: game session updated." +
            "\n==============================="
        );
    }

    private void OnProcessTerminate()
    {
        GD.Print(
            "===============================\n" +
            "GameLift: process terminating..." +
            "\n==============================="
        );

        GameLiftServerAPI.ProcessEnding();

        GetTree().Quit();
    }

    private bool OnHealthCheck()
    {
        return true;
    }

    async private void StartEmptyServerTimer()
    {
        GD.Print(
            "===============================\n" +
            "starting empty server timer..." +
            "\n==============================="
        );
        //Test Timer: After 10 minutes, if no players have connected, shut down the server
        await ToSignal(GetTree().CreateTimer(600), SceneTreeTimer.SignalName.Timeout);

        GD.Print(
            "===============================\n" +
            "GameLift: no players connected after 10 minutes, shutting down..." +
            "\n==============================="
        );

        var outcome = GameLiftServerAPI.ProcessEnding();

        if (!outcome.Success)
        {
            GD.PrintErr(
                "===============================\n" +
                "ProcessEnding failed: " +
                outcome.Error.ErrorMessage +
                "\n==============================="
            );
        }
        else
        {
            GD.Print(
                "===============================\n" +
                "ProcessEnding succeeded" +
                "\n==============================="
            );
        }

        GetTree().Quit();
    }
}