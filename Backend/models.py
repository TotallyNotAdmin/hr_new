from enum import Enum


class Role(str, Enum):
    MANAGER = "manager"
    APPROVER = "approver"
    EXECUTOR = "executor"


class RequestStatus(str, Enum):
    DRAFT = "DRAFT"
    ON_APPROVAL = "ON_APPROVAL"
    RETURNED = "RETURNED"
    REJECTED = "REJECTED"
    APPROVED = "APPROVED"
    IN_PROGRESS = "IN_PROGRESS"
    DONE = "DONE"
