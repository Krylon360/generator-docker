FROM <%= baseImageName %><% if (environment === 'debug') { %>
ARG CLRDBG_VERSION=VS2015U2
ADD https://raw.githubusercontent.com/Microsoft/MIEngine/getclrdbg-release/scripts/GetClrDbg.sh /clrdbg/
WORKDIR /clrdbg
RUN chmod 700 GetClrDbg.sh
RUN ./GetClrDbg.sh $CLRDBG_VERSION<% } %>
COPY project.json /app/
WORKDIR /app
RUN ["dotnet", "restore"]
COPY . /app<% if (environment === 'debug') { %>
RUN ["dotnet", "build", "-c", "Debug"]<% } else { %>
RUN ["dotnet", "build", "-c", "Release"]<% } %>
EXPOSE <%= portNumber %><% if (environment === 'debug') { %>
ENTRYPOINT ["/bin/bash", "-c", "if [ -z \"$REMOTE_DEBUGGING\" ]; then dotnet run /app/bin/Debug/netcoreapp1.0/app.dll; else sleep infinity; fi"]<% } else { %>
ENTRYPOINT ["dotnet", "run"]<% } %>
