using Grpc.Core;
using System.Diagnostics;
using System.Security.AccessControl;
using System.Runtime.InteropServices;
using Windows.Win32;
using Windows.Win32.Foundation;
using Windows.Win32.System.Console;
using Windows.Win32.System.Threading;
using System.IO.Pipes;
using Microsoft.Win32.SafeHandles;
using System.Text;
using System.Security.Principal;
using Microsoft.AspNetCore.Mvc.ApplicationModels;
using System;
using System.Buffers;
namespace ProxyChocoGrpcService.Services

{
    public class ChocoService : ProxyChocoService.ProxyChocoServiceBase
    {
        private readonly ILogger<ChocoService> _logger;

        public ChocoService(ILogger<ChocoService> logger)
        {
            _logger = logger;
        }
      
        
        public override async Task PseudoConsoleExecCommand(IAsyncStreamReader<CommandRequest> requestStream, IServerStreamWriter<CommandResponse> responseStream, ServerCallContext context)
        {
            ClosePseudoConsoleSafeHandle hPC = new ClosePseudoConsoleSafeHandle();

            IntPtr hPCHandDang = IntPtr.Zero;
            try
            {  
                //get args from client
                await requestStream.MoveNext();
                var firstRequest = requestStream.Current;
                string argstring = firstRequest.Command; 
                string path = firstRequest.Path;
                int X = firstRequest.X;
                int Y = firstRequest.Y;

                //set pseudo console for process

                
                SafeFileHandle hOutputWrite, hOutputRead;
                SafeFileHandle hInputWrite, hInputRead;

                if(!PInvoke.CreatePipe(out hInputRead,out hInputWrite, null, 0))
                {
                    throw new Exception(Marshal.GetLastPInvokeErrorMessage()) ;
                };

                if (!PInvoke.CreatePipe(out hOutputRead, out hOutputWrite, null, 0))
                {
                    throw new Exception(Marshal.GetLastPInvokeErrorMessage());
                };



                COORD size = new COORD { X = (short)X, Y = (short)Y };

                HRESULT ff = PInvoke.CreatePseudoConsole(size,hInputRead,hOutputWrite,0, out hPC);

                hPCHandDang = (HANDLE)hPC.DangerousGetHandle();

                STARTUPINFOEXW startupInfo = new STARTUPINFOEXW();

                PROCESS_INFORMATION processInformation;

                unsafe{

                    nuint lpSizeInit = 0 ;
                    LPPROC_THREAD_ATTRIBUTE_LIST inB = new LPPROC_THREAD_ATTRIBUTE_LIST();

                    bool isInited = PInvoke.InitializeProcThreadAttributeList(inB, 1,  ref lpSizeInit);
                    int initError = Marshal.GetLastWin32Error();
                    
                    if (!isInited && initError == 122)
                    {
                        startupInfo.lpAttributeList = (LPPROC_THREAD_ATTRIBUTE_LIST)PInvoke.HeapAlloc( PInvoke.GetProcessHeap(), 0, lpSizeInit);
                        bool isInitInStruct = PInvoke.InitializeProcThreadAttributeList(startupInfo.lpAttributeList, 1, ref lpSizeInit);
                        if (isInitInStruct)
                        {
                            
                            int sizeHPC = Marshal.SizeOf(hPCHandDang);
                            bool isUpdated = PInvoke.UpdateProcThreadAttribute(
                            startupInfo.lpAttributeList,
                            0,
                            PInvoke.PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
                            (void*)hPC.DangerousGetHandle(),
                            (uint)sizeHPC
                            );
                            if (!isUpdated)
                            {

                                throw new Exception(Marshal.GetLastPInvokeErrorMessage());
                            }
                        }
                        else
                        {

                            throw new Exception(Marshal.GetLastPInvokeErrorMessage());
                        }
                    }
                    else
                    {

                        throw new Exception($"������ {initError} ��� ������ ������ InitializeProcThreadAttributeList!");
                    }
                    ;
                    
                
                }
                startupInfo.StartupInfo.cb = (uint)Marshal.SizeOf(typeof(STARTUPINFOEXW));
                
                string command = "choco.exe " + argstring + "\0";
                //using var memoryOwner = new MemoryOwner<char>(command.ToCharArray());
                Memory<char> mem = new Memory<char>(command.ToCharArray());


                unsafe
                {
                    bool isStarted = WinApi.CreateProcess(
                     null,
                     ref mem,
                     null,
                     null,
                     true,
                     PROCESS_CREATION_FLAGS.EXTENDED_STARTUPINFO_PRESENT,
                     null,
                     path,
                     ref startupInfo,
                     out processInformation
                     );
                    if (!isStarted)
                    {
                        throw new Exception($"������ ��� ������� ��������: " + Marshal.GetLastPInvokeErrorMessage());
                    }

                }


                string guid = Guid.NewGuid().ToString();
                string inPipeName = $"InPipe_{guid}";
                string outPipeName = $"OutPipe_{guid}";
                await responseStream.WriteAsync(new CommandResponse { InPipe = inPipeName, OutPipe = outPipeName });


                CancellationTokenSource cts = new CancellationTokenSource();
                var token  = cts.Token;


                Task outputCallback = SendOutputAsync(outPipeName, hOutputRead, token);
                Task inputCallback = GetInputAsync(inPipeName, hInputWrite, token);
                PInvoke.WaitForSingleObject(processInformation.hProcess, 100000000);

                cts.Cancel();



                await Task.WhenAll(outputCallback, inputCallback);

                await responseStream.WriteAsync(new CommandResponse {Exit = "exit" });

                
                Console.WriteLine($"Pipes {guid} is stopped");

            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                PInvoke.ClosePseudoConsole((HPCON)hPCHandDang);
                throw new RpcException(new Status(StatusCode.Internal, "Internal error"));

            }
            finally
            {
                PInvoke.ClosePseudoConsole((HPCON)hPCHandDang);
                Console.WriteLine($"{hPC.IsClosed} {hPC.IsInvalid}");
            }
        }
        static async Task GetInputAsync(string inPipeName, SafeFileHandle hInputWrite, CancellationToken cts)
        {
            try
            {
                var authenticatedUsersSid = new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null);

                var pipeSecurity = new PipeSecurity();
                pipeSecurity.SetAccessRule(new PipeAccessRule(authenticatedUsersSid, PipeAccessRights.ReadWrite, AccessControlType.Allow ));
                using var inPipeStream =  NamedPipeServerStreamAcl.Create(inPipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Message, PipeOptions.None,0,0,pipeSecurity);
                await inPipeStream.WaitForConnectionAsync();
                FileStream fStreamOutput = new FileStream(hInputWrite, FileAccess.ReadWrite);
                try
                {
                    await inPipeStream.CopyToAsync(fStreamOutput, cts);
                }
                catch (OperationCanceledException)
                {
                    Console.WriteLine("������ ���� ��������.");
                }
                

            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                throw new RpcException(new Status(StatusCode.Internal, "Internal error"));

            }
        }
        static async Task SendOutputAsync(string outPipeName, SafeFileHandle hOutputRead, CancellationToken cts)
        {           
            try
            {
                 var authenticatedUsersSid = new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null);

                var pipeSecurity = new PipeSecurity();
                pipeSecurity.SetAccessRule(new PipeAccessRule(authenticatedUsersSid, PipeAccessRights.ReadWrite, AccessControlType.Allow));
                using var outPipeStream =  NamedPipeServerStreamAcl.Create(outPipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Message, PipeOptions.None,0,0,pipeSecurity);
                await outPipeStream.WaitForConnectionAsync();
                FileStream fStreamOutput = new FileStream(hOutputRead,FileAccess.Read);
                try
                {
                    await fStreamOutput.CopyToAsync(outPipeStream, cts);
                }
                catch (OperationCanceledException)
                {
                    Console.WriteLine("������ ���� ��������.");
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
