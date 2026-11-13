local WorkerPool = {}
WorkerPool.__index = WorkerPool

function WorkerPool.new(options)
    local self = setmetatable(options, WorkerPool)
    self.Queue = {}
    self.QueueHead = 1
    self.QueueTail = 0
    self.ActiveWorkers = 0
    self.ManagerGeneration = 0
    self.IsDestroyed = false
    self.TaskLibrary = options.TaskLibrary or task
    self:Reset()
    return self
end

function WorkerPool:QueueOperation(...)
    if self.IsDestroyed then return end
    self.QueueTail += 1
    self.Queue[self.QueueTail] = table.pack(...)
    self:DrainQueue()
end

function WorkerPool:DrainQueue(expectedGeneration)
    if self.IsDestroyed then return end
    if expectedGeneration ~= nil and self.ManagerGeneration ~= expectedGeneration then return end

    local managerGeneration = self.ManagerGeneration
    while self.ActiveWorkers < self.MaxConcurrent and self.QueueHead <= self.QueueTail do
        local taskData = self.Queue[self.QueueHead]
        self.Queue[self.QueueHead] = nil
        self.QueueHead += 1
        if not taskData then continue end

        self.ActiveWorkers += 1
        self.TaskLibrary.defer(function()
            local currentTask = taskData
            while currentTask do
                if not self.IsDestroyed and self.ManagerGeneration == managerGeneration then
                    local callbackOk, callbackError = pcall(
                        self.MainCallback,
                        table.unpack(currentTask, 1, currentTask.n)
                    )
                    if not callbackOk then
                        if self.OnError then
                            pcall(
                                self.OnError,
                                callbackError,
                                table.unpack(currentTask, 1, currentTask.n)
                            )
                        end
                    end
                end

                if self.IsDestroyed or self.ManagerGeneration ~= managerGeneration or self.ActiveWorkers > self.MaxConcurrent then
                    break
                end

                if self.QueueHead <= self.QueueTail then
                    currentTask = self.Queue[self.QueueHead]
                    self.Queue[self.QueueHead] = nil
                    self.QueueHead += 1
                else
                    currentTask = nil
                end
            end

            self.ActiveWorkers = math.max(0, self.ActiveWorkers - 1)
            self:DrainQueue()
        end)
    end
end

function WorkerPool:Reset()
    if self.IsDestroyed then return end
    self.Queue = {}
    self.QueueHead = 1
    self.QueueTail = 0
    self.ManagerGeneration += 1
    self:DrainQueue()
end

function WorkerPool:SetMaxConcurrent(maxConcurrent)
    self.MaxConcurrent = math.max(1, math.floor(tonumber(maxConcurrent) or 1))
    self:DrainQueue()
end

function WorkerPool:Destroy()
    if self.IsDestroyed then return end
    self.IsDestroyed = true
    table.clear(self.Queue)
    self.QueueHead = 1
    self.QueueTail = 0
end

WorkerPool.Stop = WorkerPool.Destroy

return WorkerPool
