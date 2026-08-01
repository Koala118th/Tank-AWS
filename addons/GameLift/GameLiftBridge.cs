using Godot;
using Aws.GameLift.Server;
using Aws.GameLift.Server.Model;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using System;

public partial class GameLiftBridge : Node
{
    private Node _gdServer;

    private void ConfigureLogging() //Disables log4net console output and configures a file appender for logging
    {
        log4net.Util.LogLog.QuietMode = true;

        const string logDir = "/local/game/logs";
        System.IO.Directory.CreateDirectory(logDir);

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
            File = System.IO.Path.Combine(logDir, "gamelift-full.log"),
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

        var logParameters = new LogParameters(new List<string>
            {
                "/local/game/logs/gamelift-full.log"
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
    private CancellationTokenSource _emptyTimerCts;

    public void StartEmptyServerTimer()
    {
        StopEmptyServerTimer();

        _emptyTimerCts = new CancellationTokenSource();
        _ = RunEmptyServerTimer(_emptyTimerCts.Token);
    }

    public void StopEmptyServerTimer()
    {
        if (_emptyTimerCts == null)
            return;

        _emptyTimerCts.Cancel();
        _emptyTimerCts.Dispose();
        _emptyTimerCts = null;

        GD.Print(
            "===============================\n" +
            "Empty server timer stopped — a player is connected." +
            "\n==============================="
        );
    }

    private async Task RunEmptyServerTimer(CancellationToken token)
    {
        GD.Print(
            "===============================\n" +
            "starting empty server timer..." +
            "\n==============================="
        );

        try
        {
            await Task.Delay(TimeSpan.FromSeconds(300), token);
        }
        catch (TaskCanceledException)
        {
            return;
        }

        GD.Print(
            "===============================\n" +
            "GameLift: no players connected after 5 minutes, shutting down..." +
            "\n==============================="
        );

        var outcome = GameLiftServerAPI.ProcessEnding();

        if (!outcome.Success)
        {
            GD.PrintErr("ProcessEnding failed: " + outcome.Error.ErrorMessage);
        }
        else
        {
            GD.Print("ProcessEnding succeeded");
        }

        GetTree().Quit();
    }
}