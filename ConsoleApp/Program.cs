using Grpc.Core;
using Grpc.Net.Client;
using System;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Windows.Win32;
using Windows.Win32.Foundation;
using Windows.Win32.System.Console;

namespace ProxyChocoGrpcServiceClient
{
    class Program
    {

        
        static async Task Main(string[] args)
        {
            // Create the gRPC channel
            using var channel = GrpcChannel.ForAddress("http://localhost:5000", new GrpcChannelOptions
            {
                MaxSendMessageSize = 50 * 1024 * 1024,
                MaxReceiveMessageSize = 50 * 1024 * 1024
            });

            var client = new ProxyChocoService.ProxyChocoServiceClient(channel);
            var initForegroundColor = Console.ForegroundColor;
            var initBackgroundColor = Console.BackgroundColor;
            var cts = new CancellationTokenSource();
            var token = cts.Token;

            try
            {
                var call = client.PseudoConsoleExecCommand(cancellationToken: token);

                await call.RequestStream.WriteAsync(new CommandRequest
                {
                    Command = string.Join(" ", args),
                    Path = Directory.GetCurrentDirectory(),
                    X = Console.WindowWidth,
                    Y = Console.WindowHeight
                    
                });

                bool isWorks = true;
                await call.ResponseStream.MoveNext();
                var response = call.ResponseStream.Current;

                if (response.InPipe != null && response.OutPipe != null)
                {
                    try
                    {
                        SafeHandle hOutput = PInvoke.GetStdHandle_SafeHandle(Windows.Win32.System.Console.STD_HANDLE.STD_OUTPUT_HANDLE);
                        HANDLE hOutputD = PInvoke.GetStdHandle(STD_HANDLE.STD_OUTPUT_HANDLE);

                        CONSOLE_SCREEN_BUFFER_INFOEX infoEx = new CONSOLE_SCREEN_BUFFER_INFOEX();

                        CONSOLE_MODE currentMode;

                        PInvoke.GetConsoleMode(hOutput, out currentMode);

                        PInvoke.SetConsoleMode(hOutput, currentMode | CONSOLE_MODE.ENABLE_VIRTUAL_TERMINAL_PROCESSING);

                        const uint ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;

                        Task InputCallback = SendInputAsync(response.InPipe, token);
                        Task OutputCallback = GetOutputAsync(response.OutPipe, token);

                        await call.ResponseStream.MoveNext();
                        var exitResponse = call.ResponseStream.Current;

                        if (exitResponse.Exit == "exit")
                        {

                            cts.Cancel();

                        }

                        await Task.WhenAny(OutputCallback, InputCallback);
                        Console.ForegroundColor = initForegroundColor;
                        Console.BackgroundColor = initBackgroundColor;


                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Error: {ex.Message}");
                        throw new RpcException(new Status(StatusCode.Internal, "Internal error"));

                    }

                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }

        }
        static async Task SendInputAsync(string inPipeName, CancellationToken token)
        {
            try
            {
                using (NamedPipeClientStream inPipe = new NamedPipeClientStream(".", inPipeName, PipeDirection.InOut))
                {
                    using (Stream inputStream = Console.OpenStandardInput()) {
                        await inPipe.ConnectAsync(cancellationToken: token);
                        
                        try
                        {

                            await inputStream.CopyToAsync(destination: inPipe, cancellationToken: token);
                        }
                        catch (OperationCanceledException)
                        {
                         
                        }
                    };                 
                }
            }
                
                
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                throw new RpcException(new Status(StatusCode.Internal, "Internal error"));

            }

        }
        static async Task GetOutputAsync(string outPipeName, CancellationToken token)
        {
            try
            {
                using var outPipe = new NamedPipeClientStream(".", outPipeName, PipeDirection.InOut);
                await outPipe.ConnectAsync();
                try
                {
                    await outPipe.CopyToAsync(Console.OpenStandardOutput(), token);

                }
                catch (OperationCanceledException) {


                }

            }
            catch (Exception ex)
            {
                    Console.WriteLine($"Error: {ex.Message}");
                    throw new RpcException(new Status(StatusCode.Internal, "Internal error"));
                }

        }
    }    
}
